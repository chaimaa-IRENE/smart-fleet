import React, { useState, useRef, useEffect, useCallback } from "react";
import axios from "axios";
import {
  Mic, MicOff, Send, Volume2, VolumeX, RefreshCw, CheckCircle,
  XCircle, Loader2, AlertCircle, Truck, MapPin, Calendar,
  Wrench, Shield, FileText, MessageCircle, Bot, User
} from "lucide-react";

import { API_BASE as API, TTS_BASE as TTS_API } from "../config/api";

const Recognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
const isEdge = navigator.userAgent.indexOf("Edg") !== -1;
const isChrome = navigator.userAgent.indexOf("Chrome") !== -1 && !isEdge;
const sttSupported = !!Recognition;

/* ── Normalise immatriculation marocaine ───────────────────────
 *  Formats acceptés (oral ou écrit) :
 *    "12345 b c"  "12345bc"  "12345-b-6"  "un deux trois quatre cinq b c"
 *    "١٢٣٤٥ ب ج" (chiffres/lettres arabes)
 *    "12345 alif ba"  (noms de lettres arabes/français)
 *  Résultat : "12345-B-C" ou "12345-BC-6"
 */
const AR_DIGIT: Record<string, string> = {
  "\u0660":"0","\u0661":"1","\u0662":"2","\u0663":"3","\u0664":"4",
  "\u0665":"5","\u0666":"6","\u0667":"7","\u0668":"8","\u0669":"9",
};
const AR_LETTER: Record<string, string> = {
  "\u0627":"A","\u0628":"B","\u062C":"J","\u062F":"D","\u0647":"H",
  "\u0648":"W","\u0632":"Z","\u0637":"T","\u064A":"Y","\u0643":"K",
  "\u0644":"L","\u0645":"M","\u0646":"N","\u0633":"S","\u0639":"E",
  "\u0641":"F","\u0642":"Q","\u0631":"R","\u0634":"CH","\u062A":"T",
  "\u062B":"TH","\u062E":"KH","\u0630":"DH","\u0636":"DH","\u0635":"S",
  "\u063A":"GH","\u0629":"H",
};
const FR_WORDS: Record<string, string> = {
  "un":"1","deux":"2","trois":"3","quatre":"4","cinq":"5","six":"6",
  "sept":"7","huit":"8","neuf":"9","zéro":"0","zero":"0","dix":"10",
  "onze":"11","douze":"12","treize":"13","quatorze":"14","quinze":"15",
  "seize":"16","vingt":"20","trente":"30","cent":"00","cents":"00",
  "mille":"000","million":"000000","millions":"000000",
};
/* Noms de nombres arabes (prononcés à l'oral) → chiffres */
const AR_NUM: Record<string, string> = {
  "\u0648\u0627\u062D\u062F":"1","\u0648\u0627\u062D\u062F\u0629":"1",
  "\u0627\u062B\u0646\u0627\u0646":"2","\u0627\u062B\u0646\u064A\u0646":"2",
  "\u062B\u0644\u0627\u062B\u0629":"3","\u062B\u0644\u0627\u062B":"3",
  "\u0623\u0631\u0628\u0639\u0629":"4","\u0623\u0631\u0628\u0639":"4",
  "\u0627\u0631\u0628\u0639\u0629":"4","\u0627\u0631\u0628\u0639":"4",
  "\u062E\u0645\u0633\u0629":"5","\u062E\u0645\u0633":"5",
  "\u0633\u062A\u0629":"6","\u0633\u062A":"6",
  "\u0633\u0628\u0639\u0629":"7","\u0633\u0628\u0639":"7",
  "\u062B\u0645\u0627\u0646\u064A\u0629":"8","\u062B\u0645\u0627\u0646":"8",
  "\u062A\u0633\u0639\u0629":"9","\u062A\u0633\u0639":"9",
  "\u0639\u0634\u0631\u0629":"10","\u0639\u0634\u0631":"10",
  "\u0623\u0644\u0641":"1000",
};
/* Translitération darija/francisée des nombres */
const AR_NUM_TR: Record<string, string> = {
  "wahid":"1","wa7id":"1","jouj":"2","tleta":"3","tlata":"3",
  "rb3a":"4","arba":"4","khamsa":"5","5msa":"5",
  "sitta":"6","sita":"6","sba3":"7","saba3":"7","sb3a":"7",
  "tmnya":"8","tminya":"8","ts3od":"9","tsa3od":"9",
  "alf":"1000",
};
/* Noms de lettres arabes → lettre latine de plaque marocaine */
const AR_NAME: Record<string, string> = {
  "alif":"A","alef":"A","ba":"B","be":"B","ta":"T","te":"T",
  "dal":"D","dhal":"D","ra":"R","re":"R","r":"R",
  "sin":"S","sine":"S","seen":"S","fa":"F","fe":"F","kaf":"K","kef":"K","qaf":"Q","lam":"L","lem":"L",
  "mim":"M","mem":"M","m":"M","nun":"N","noun":"N","n":"N",
  "waw":"W","ouaou":"W","ha":"H","he":"H","ya":"Y","ye":"Y",
  "zay":"Z","ze":"Z","jeem":"J","jim":"J","j":"J","ain":"A",
  "gh":"GH","ghayn":"GH","kha":"KH","tha":"TH","ch":"CH",
};
const FR_LETTRE: Record<string, string> = {
  "a":"A", "ah":"A", "be":"B", "bé":"B", "ce":"C", "cé":"C",
  "de":"D", "dé":"D", "e":"E", "eu":"E", "effe":"F",
  "ge":"G", "gé":"G", "hache":"H", "ache":"H",
  "i":"I", "ji":"J", "ka":"K", "ke":"K",
  "elle":"L", "emme":"M", "enne":"N",
  "o":"O", "pe":"P", "pé":"P", "ku":"Q",
  "erre":"R", "esse":"S",
  "te":"T", "té":"T", "u":"U", "ve":"V", "vé":"V",
  "double ve":"W", "iks":"X", "i grec":"Y", "i grecque":"Y",
  "zed":"Z", "zède":"Z", "ze":"Z",
};
function normalizeImmatriculation(raw: string): string {
  let s = raw.trim().toLowerCase();
  s = s.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  for (const [w, d] of Object.entries(FR_WORDS)) {
    s = s.replace(new RegExp(`\\b${w}\\b`, "gi"), d);
  }
  for (const [num, d] of Object.entries(AR_NUM)) {
    s = s.replace(new RegExp(num, "gi"), d);
  }
  for (const [tr, d] of Object.entries(AR_NUM_TR)) {
    s = s.replace(new RegExp(`\\b${tr}\\b`, "gi"), d);
  }
  for (const [fr, letter] of Object.entries(FR_LETTRE)) {
    s = s.replace(new RegExp(`\\b${fr}\\b`, "gi"), letter);
  }
  for (const [name, letter] of Object.entries(AR_NAME)) {
    s = s.replace(new RegExp(`\\b${name}\\b`, "gi"), letter);
  }
  s = s.replace(/[\u0660-\u0669]/g, c => AR_DIGIT[c] || c);
  s = s.replace(/[\u0600-\u06FF]/g, c => AR_LETTER[c] || "");
  s = s.replace(/[|\-\/\s]+/g, "").toUpperCase();
  const m1 = s.match(/^(\d+)([A-Z]+)(\d*)$/);
  if (m1) {
    const [, d1, letters, d2] = m1;
    return d2 ? `${d1}-${letters}-${d2}` : `${d1}-${letters}`;
  }
  const m2 = s.match(/^([A-Z]+)(\d+)([A-Z]+)$/);
  if (m2) {
    const [, letters1, digits, letters2] = m2;
    return `${letters1}-${digits}-${letters2}`;
  }
  return s || raw.toUpperCase();
}

const D2A: [string, string][] = [
  ["sm7 lia", "\u0633\u0645\u062D \u0644\u064A\u0627"],
  ["l3ammar", "\u0644\u0639\u0645\u0651\u0627\u0631"],
  ["nsawelk", "\u0646\u0633\u0627\u0648\u0644\u0643"],
  ["msta3ed", "\u0645\u0633\u062A\u0639\u062F"],
  ["t3awed", "\u062A\u0639\u0627\u0648\u062F"],
  ["3andna", "\u0639\u0646\u062F\u0646\u0627"],
  ["3andek", "\u0639\u0646\u062F\u0643"],
  ["kifach", "\u0643\u064A\u0641\u0627\u0634"],
  ["kifash", "\u0643\u064A\u0641\u0627\u0634"],
  ["hadchi", "\u0647\u0627\u062F\u0634\u064A"],
  ["makaynch", "\u0645\u0627\u0643\u064A\u0646\u0634"],
  ["3ammar", "\u0639\u0645\u0651\u0631"],
  ["n3ammar", "\u0646\u0639\u0645\u0651\u0631"],
  ["tbriya", "\u0637\u0628\u0631\u064A\u0629"],
  ["cassat", "\u0643\u0635\u0627\u062A"],
  ["kadour", "\u0643\u064A\u062F\u0648\u0631"],
  ["lfaran", "\u0627\u0644\u0641\u0631\u0627\u0646"],
  ["l9eddan", "\u0627\u0644\u0642\u062F\u0627\u0645"],
  ["lkhoura", "\u0627\u0644\u062E\u0644\u0641\u0629"],
  ["bari7", "\u0627\u0644\u0628\u0627\u0631\u062D"],
  ["lyouma", "\u0627\u0644\u064A\u0648\u0645"],
  ["kaydir", "\u0643\u0627\u064A\u062F\u064A\u0631"],
  ["3awed", "\u0639\u0627\u0648\u062F"],
  ["m3akom", "\u0645\u0639\u0627\u0643\u0645"],
  ["wa9ef", "\u0648\u0627\u0642\u0641"],
  ["bghit", "\u0628\u063A\u064A\u062A"],
  ["mochkil", "\u0645\u0634\u0643\u0644"],
  ["immatriculation", "\u0625\u0645\u0627\u062A\u0631\u064A\u0643\u0648\u0644\u0627\u0633\u064A\u0648\u0646"],
  ["declaration", "\u062A\u0635\u0631\u064A\u062D"],
  ["camion", "\u0643\u0627\u0645\u064A\u0648"],
  ["panne", "\u0639\u0637\u0644"],
  ["ma9f", "\u0645\u0648\u0642\u0641"],
  ["t9eb", "\u062A\u0642\u0628"],
  ["wakha", "\u0648\u0627\u062E\u0627"],
  ["walou", "\u0648\u0627\u0644\u0648"],
  ["mashi", "\u0645\u0627\u0634\u064A"],
  ["b7al", "\u0628\u062D\u0627\u0644"],
  ["mzyan", "\u0645\u0632\u064A\u0627\u0646"],
  ["khoya", "\u062E\u0648\u064A\u0627"],
  ["b9it", "\u0628\u0642\u064A\u062A"],
  ["b9a", "\u0628\u0642\u0649"],
  ["3lach", "\u0639\u0644\u0627\u0634"],
  ["3tik", "\u0646\u0639\u0637\u064A\u0643"],
  ["ghadi", "\u063A\u0627\u062F\u064A"],
  ["s7i7", "\u0635\u062D"],
  ["wach", "\u0648\u0627\u0634"],
  ["nta", "\u0646\u062A\u0627"],
  ["goul", "\u0642\u0648\u0644"],
  ["naw3", "\u0646\u0648\u0639"],
  ["dial", "\u062F\u064A\u0627\u0644"],
  ["dyal", "\u062F\u064A\u0627\u0644"],
  ["kayn", "\u0643\u064A\u0646"],
  ["fin", "\u0641\u064A\u0646"],
  ["imta", "\u064A\u0645\u062A\u0627"],
  ["casse", "\u0643\u0635"],
  ["s3a", "\u0633\u0627\u0639\u0629"],
  ["m3ak", "\u0645\u0639\u0627\u0643"],
  ["btabt", "\u0628\u062F\u0642\u0629"],
  ["bdabt", "\u0628\u062F\u0642\u0629"],
  ["3ti", "\u0639\u0637\u064A"],
  ["ah", "\u0622\u0647"],
  ["oui", "\u0648\u064A"],
  ["wah", "\u0648\u0627\u0647"],
  ["na3am", "\u0646\u0639\u0645"],
  ["salam", "\u0633\u0644\u0627\u0645"],
  ["nssajel", "\u0646\u0633\u062C\u0651\u0644"],
  ["chno", "\u0634\u0646\u0648"],
  ["bda", "\u0628\u062F\u0649"],
  ["la", "\u0644\u0627"],
  ["7aja", "\u062D\u0627\u062C\u0629"],
  ["7ad", "\u062D\u062F"],
  ["mzyan", "\u0645\u0632\u064A\u0627\u0646"],
  ["chof", "\u0634\u0648\u0641"],
  ["koun", "\u0643\u0648\u0646"],
  ["9al3a", "\u0642\u0644\u0639\u0629"],
  ["jwaj", "\u062C\u0648\u062C"],
  ["zyada", "\u0632\u064A\u0627\u062F\u0629"],
  ["bzzaf", "\u0628\u0632\u0627\u0641"],
  ["chwiya", "\u0634\u0648\u064A\u0629"],
  ["baraka", "\u0628\u0631\u0643\u0629"],
  ["sir", "\u0633\u064A\u0631"],
  ["dir", "\u062F\u064A\u0631"],
  ["sma3ni", "\u0633\u0645\u0639\u0646\u064A"],
  ["3awnek", "\u0639\u0627\u0648\u0646\u0643"],
  ["ghadi", "\u063A\u0627\u062F\u064A"],
  ["nbdaou", "\u0646\u0628\u062F\u0627\u0648"],
  ["hadi", "\u0647\u0627\u062F\u064A"],
  ["daba", "\u062F\u0627\u0628\u0627"],
  ["baraka", "\u0628\u0631\u0643\u0629"],
  ["tfaddel", "\u062A\u0641\u0636\u0644"],
  ["darouri", "\u0636\u0631\u0648\u0631\u064A"],
  ["chwya", "\u0634\u0648\u064A\u0629"],
  ["kashi", "\u0643\u0627\u0634\u064A"],
  ["blokan", "\u0628\u0644\u0648\u0643\u0627\u0646"],
  ["mablok", "\u0645\u0628\u0644\u0648\u0643"],
  ["makanik", "\u0645\u0643\u0627\u0646\u064A\u0643"],
  ["kays", "\u0643\u062A\u0633"],
  ["kabine", "\u0643\u0627\u0628\u064A\u0646"],
  ["batoun", "\u0628\u0627\u062A\u0648\u0646"],
  ["dio", "\u0636\u0648"],
  ["broud", "\u0628\u0631\u0648\u062F"],
  ["warrak", "\u0648\u0631\u0627\u0642"],
  ["khoya", "\u062E\u0648\u064A\u0627"],
  ["khweya", "\u062E\u0648\u064A\u0627"],
  ["tbarak", "\u062A\u0628\u0627\u0631\u0643"],
  ["allah", "\u0627\u0644\u0644\u0647"],
  ["validi", "\u0648\u0627\u0644\u064A\u064A\u062F\u064A"],
  ["beddel", "\u0628\u062F\u0644\u0648"],
  ["machi", "\u0645\u0627\u0634\u064A"],
  ["kifach", "\u0643\u064A\u0641\u0627\u0634"],
  ["goul liya", "\u0642\u0648\u0644 \u0644\u064A\u0627"],
  ["3ti lya", "\u0639\u0637\u064A \u0644\u064A\u0627"],
  ["chhal", "\u0634\u062D\u0627\u0644"],
  ["fhamtch", "\u0641\u0647\u0645\u062A\u0634"],
  ["no3", "\u0646\u0648\u0639"],
  ["haw arrija", "\u0627\u0644\u0645\u0634\u0643\u0644"],
  ["kayn", "\u0643\u0627\u064A\u0646"],
  ["tayara", "\u0637\u064A\u0627\u0631"],
  ["utanawid", "\u062A\u0641\u0627\u0635\u064A\u0644"],
  ["zyada", "\u0632\u064A\u0627\u062F\u0629"],
  ["kawtch", "\u0643\u0627\u0648\u062A\u0634"],
  ["casa", "\u0643\u0627\u0632\u0627"],
  ["rbat", "\u0631\u0628\u0627\u0637"],
  ["marra", "\u0645\u0631\u0627\u0643\u0634"],
  ["tanja", "\u0637\u0646\u062C\u0629"],
  ["fes", "\u0641\u0627\u0633"],
  ["lyoum", "\u0627\u0644\u064A\u0648\u0645"],
  ["imta", "\u0625\u0645\u062A\u0649"],
  ["3ti", "\u0639\u0637\u064A"],
  ["plaak", "\u0627\u0644\u0628\u0644\u0627\u0643"],
  ["tssadjlat", "\u062A\u0633\u062C\u0644"],
  ["ntaya", "\u0646\u062A\u0627\u064A\u0627"],
  ["nta", "\u0646\u062A\u0627"],
  ["msta3ed", "\u0645\u0633\u062A\u0639\u062F"],
  ["nbdew", "\u0646\u0628\u062F\u0627\u0648"],
  ["nbdaou", "\u0646\u0628\u062F\u0627\u0648"],
  ["n3awnk", "\u0646\u0639\u0627\u0648\u0646\u0643"],
  ["n3awnek", "\u0646\u0639\u0627\u0648\u0646\u0643"],
  ["f'camion", "\u0641\u0644\u0643\u0627\u0645\u064A\u0648"],
  ["l'camion", "\u0644\u0643\u0627\u0645\u064A\u0648"],
  ["l'tarik", "\u0644\u062A\u0627\u0631\u064A\u062E"],
  ["l'wel", "\u0644\u0648\u0644"],
  ["l'awwal", "\u0644\u0623\u0648\u0644"],
  ["sma3ntkch", "\u0633\u0645\u0639\u062A\u0643\u0634"],
  ["nvalidiw", "\u0646\u0641\u0627\u0644\u064A\u062F\u064A\u0648"],
  ["tbeddel", "\u062A\u0628\u062F\u0644"],
  ["n'sjjel", "\u0646\u0633\u062C\u0644"],
  ["n'mero", "\u0646\u0645\u0631\u0648"],
  ["l'ikhtiyarat", "\u0644\u0627\u062E\u062A\u064A\u0627\u0631\u0627\u062A"],
  ["r'9am", "\u0631\u0642\u0645"],
  ["l'panne", "\u0644\u0628\u0627\u0646"],
  ["d'l'plaak", "\u062F\u064A\u0627\u0644 \u0627\u0644\u0628\u0644\u0627\u0643"],
  ["d'camion", "\u062F\u064A\u0627\u0644 \u0644\u0643\u0627\u0645\u064A\u0648"],
  ["d'la blasa", "\u062F\u064A\u0627\u0644 \u0627\u0644\u0628\u0644\u0627\u0635\u0629"],
  ["f'camion", "\u0641\u0644\u0643\u0627\u0645\u064A\u0648"],
  ["l'boton", "\u0628\u0648\u0637\u0648\u0646"],
  ["b'dabt", "\u0628\u0627\u0644\u0636\u0628\u0637"],
  ["zayed", "\u0632\u0627\u064A\u062F"],
  ["l'fahs", "\u0644\u0641\u062D\u0635"],
  ["s'sayana", "\u0627\u0644\u0635\u064A\u0627\u0646\u0629"],
  ["l'capteur", "\u0644\u0643\u0627\u0628\u062A\u0648\u0631"],
  ["l'clim", "\u0644\u0643\u0644\u064A\u0645"],
  ["l'frigo", "\u0627\u0644\u0641\u0631\u064A\u062C\u0648"],
  ["l'broud", "\u0627\u0644\u0628\u0631\u0648\u062F"],
  ["l'makina", "\u0627\u0644\u0645\u0627\u0643\u064A\u0646\u0627"],
  ["l'frem", "\u0627\u0644\u0641\u0631\u0645"],
  ["l'ambriyaj", "\u0627\u0644\u0623\u0645\u0628\u0631\u064A\u0627\u062C"],
  ["s'suspension", "\u0627\u0644\u0633\u0648\u0633\u0628\u0627\u0646\u0633\u064A\u0648\u0646"],
  ["d'daw", "\u0627\u0644\u0636\u0648"],
  ["l'klaxon", "\u0627\u0644\u0643\u0644\u0627\u0643\u0633\u0648\u0646"],
  ["l'phare", "\u0627\u0644\u0641\u0627\u0631"],
  ["l'tablo", "\u0627\u0644\u0637\u0627\u0628\u0644\u0648"],
  ["l'sij", "\u0627\u0644\u0633\u064A\u062C"],
  ["l'vitre", "\u0627\u0644\u0641\u064A\u062A\u0631"],
  ["z'zontaj", "\u0627\u0644\u0632\u0648\u0646\u0637\u0627\u062C"],
  ["s'salama", "\u0627\u0644\u0633\u0644\u0627\u0645\u0629"],
  ["l'baraka", "\u0627\u0644\u0628\u0627\u0631\u0643\u0629"],
  ["l'garaaj", "\u0627\u0644\u063A\u0627\u0631\u0627\u062C"],
  ["s'sayana", "\u0627\u0644\u0635\u064A\u0627\u0646\u0629"],
  ["l'carrosserie", "\u0627\u0644\u0643\u0627\u0631\u0648\u0633\u0631\u064A"],
  ["l'hayon", "\u0627\u0644\u0647\u0627\u064A\u0648\u0646"],
  ["planchir", "\u0627\u0644\u0628\u0644\u0627\u0646\u0634\u064A\u0631"],
  ["y'panni", "\u064A\u0639\u0637\u0644"],
  ["f'l'tariq", "\u0641\u064A \u0627\u0644\u0637\u0631\u064A\u0642"],
  ["l'incident", "\u0644\u062D\u0627\u062F\u062B"],
  ["l'hada", "\u0627\u0644\u0647\u0627\u062F\u0629"],
  ["l'roujla", "\u0627\u0644\u0631\u062C\u0644\u0629"],
  ["Ch'hal", "\u0634\u062D\u0627\u0644"],
  ["ay haja", "\u0623\u064A \u062D\u0627\u062C\u0629"],
  ["l'anwa3", "\u0627\u0644\u0623\u0646\u0648\u0627\u0639"],
  ["l'kilometraj", "\u0627\u0644\u0643\u064A\u0644\u0648\u0645\u062A\u0631\u0627\u062C"],
  ["l'mourakh", "\u0644\u0645\u0639\u0631\u0648\u062E"],
  ["l'ikhtiyar", "\u0627\u0644\u0627\u062E\u062A\u064A\u0627\u0631"],
  ["f'sa3a", "\u0641\u064A \u0627\u0644\u0633\u0627\u0639\u0629"],
  ["li bghiti", "\u0644\u064A \u0628\u063A\u064A\u062A\u064A"],
  ["bghiti", "\u0628\u063A\u064A\u062A\u064A"],
  ["Amrani", "\u0639\u0645\u0631\u0627\u0646\u064A"],
  ["t3amer", "\u062A\u0639\u0645\u0631"],
  ["d\u00E9claration", "\u062A\u0635\u0631\u064A\u062D"],
  ["w9e3", "\u0648\u0642\u0639"],
  ["li", "\u0644\u064A"],
  ["kaymchi", "\u0643\u0627\u064A\u0645\u0634\u064A"],
  ["ma kaymchich", "\u0645\u0627 \u0643\u0627\u064A\u0645\u0634\u064A\u0634"],
  ["f'", "\u0641\u0640"],
  ["d'", "\u062F\u064A\u0627\u0644 "],
  ["l'", "\u0627\u0644\u0640"],
  ["s'", "\u0627\u0644\u0640"],
  ["ntaya", "\u0646\u062A\u0627\u064A\u0627"],
  ["safi", "\u0635\u0627\u0641\u064A"],
  ["kolchi", "\u0643\u0644\u0634\u064A"],
  ["bqa", "\u0628\u0642\u0649"],
  ["tbeddel", "\u062A\u0628\u062F\u0644"],
  ["nvalidiw", "\u0646\u0641\u0627\u0644\u064A\u062F\u064A\u0648"],
  ["n'sjjel", "\u0646\u0633\u062C\u0644"],
  ["l'wel", "\u0644\u0648\u0644"],
  ["khtar", "\u062E\u062A\u0627\u0631"],
  ["9bl", "\u0642\u0628\u0644"],
  ["ba3d", "\u0628\u0639\u062F"],
  ["wna", "\u0648\u0646\u0627"],
  ["ntaya", "\u0646\u062A\u0627\u064A\u0627"],
  ["ana", "\u0623\u0646\u0627"],
  ["hna", "\u0647\u0646\u0627"],
  ["t3awed", "\u062A\u0639\u0627\u0648\u062F"],
  ["kayn", "\u0643\u0627\u064A\u0646"],
  ["makaynch", "\u0645\u0627\u0643\u0627\u064A\u0646\u0634"],
  ["bass", "\u0628\u0627\u0633"],
  ["khatar", "\u062E\u0627\u0637\u0631"],
  ["mochkil", "\u0645\u0634\u0643\u0644"],
  ["blasa", "\u0628\u0644\u0627\u0635\u0629"],
  ["smiya", "\u0633\u0645\u064A\u0629"],
  ["smiyta", "\u0633\u0645\u064A\u062A\u0647\u0627"],
  ["akhra", "\u0623\u062E\u0631\u0649"],
  ["fih", "\u0641\u064A\u0647"],
  ["fiha", "\u0641\u064A\u0647\u0627"],
  ["bih", "\u0628\u064A\u0647"],
  ["bina", "\u0628\u064A\u0646\u0627"],
  ["ch?hal", "\u0634\u062D\u0627\u0644"],
  ["r'9am", "\u0631\u0642\u0645"],
  ["n'mero", "\u0646\u0645\u0631\u0648"],
];

function transliterateDarija(text: string): string {
  let r = text;
  for (const [k, v] of D2A) {
    const re = new RegExp(k.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "gi");
    r = r.replace(re, v);
  }
  r = r.replace(/3/g, "\u0639");
  r = r.replace(/7/g, "\u062D");
  r = r.replace(/9/g, "\u0642");
  r = r.replace(/5/g, "\u062E");
  r = r.replace(/6/g, "\u0637");

  const parts = r.split(/([\u0600-\u06FF]+)/);
  const out: string[] = [];
  for (const p of parts) {
    if (/^[\u0600-\u06FF]/.test(p)) {
      out.push(p);
    } else if (/^[a-zA-Z]/.test(p)) {
      let s = p.toLowerCase();
      s = s.replace(/ch/g, "\u0634");
      s = s.replace(/kh/g, "\u062E");
      s = s.replace(/gh/g, "\u063A");
      s = s.replace(/aa/g, "\u0627");
      s = s.replace(/ee/g, "\u064A");
      s = s.replace(/oo/g, "\u0648");
      s = s.replace(/ou/g, "\u0648");
      s = s.replace(/sh/g, "\u0634");
      s = s.replace(/th/g, "\u062B");
      s = s.replace(/dh/g, "\u0630");
      s = s.replace(/b/g, "\u0628");
      s = s.replace(/c/g, "\u0643");
      s = s.replace(/d/g, "\u062F");
      s = s.replace(/f/g, "\u0641");
      s = s.replace(/g/g, "\u06AF");
      s = s.replace(/h/g, "\u0647");
      s = s.replace(/j/g, "\u062C");
      s = s.replace(/k/g, "\u0643");
      s = s.replace(/l/g, "\u0644");
      s = s.replace(/m/g, "\u0645");
      s = s.replace(/n/g, "\u0646");
      s = s.replace(/p/g, "\u067E");
      s = s.replace(/q/g, "\u0642");
      s = s.replace(/r/g, "\u0631");
      s = s.replace(/s/g, "\u0633");
      s = s.replace(/t/g, "\u062A");
      s = s.replace(/v/g, "\u06A4");
      s = s.replace(/w/g, "\u0648");
      s = s.replace(/x/g, "\u0643\u0633");
      s = s.replace(/z/g, "\u0632");
      s = s.replace(/a/g, "\u0627");
      s = s.replace(/i/g, "\u064A");
      s = s.replace(/u/g, "\u0648");
      s = s.replace(/e/g, "\u064A");
      s = s.replace(/o/g, "\u0648");
      s = s.replace(/y/g, "\u064A");
      out.push(s);
    } else {
      out.push(p);
    }
  }
  return out.join("");
}

interface ChatMsg {
  type: "ai" | "user";
  text: string;
  textFr?: string;
  timestamp: Date;
}

interface VoiceDeclarationAgentProps {
  currentUser?: { id?: number; name?: string; firstname?: string; matricule?: string } | null;
  onDeclarationCreated?: (declaration: any) => void;
}

interface DarijaChoice {
  id: number;
  label_fr: string;
  label_darija: string;
  label_arabic: string;
}

interface VoiceAgentResponse {
  sessionId?: string;
  step?: number;
  field?: string;
  questionDarija?: string;
  questionFrancais?: string;
  questionArabic?: string;
  done?: boolean;
  cancelled?: boolean;
  retry?: boolean;
  retryMessage?: string;
  retryMessageFr?: string;
  error?: string;
  declarationCreated?: boolean;
  declarationId?: number;
  declaration?: any;
  formData?: Record<string, string>;
  choices?: DarijaChoice[];
}

const STEP_ICONS: Record<string, React.ReactNode> = {
  greeting: <MessageCircle className="w-4 h-4" />,
  vehicule: <Truck className="w-4 h-4" />,
  immatriculation: <Truck className="w-4 h-4" />,
  typePanne: <Wrench className="w-4 h-4" />,
  elementVehicule: <Wrench className="w-4 h-4" />,
  detailElement: <Wrench className="w-4 h-4" />,
  criticite: <Shield className="w-4 h-4" />,
  location: <MapPin className="w-4 h-4" />,
  dateHeure: <Calendar className="w-4 h-4" />,
  description: <FileText className="w-4 h-4" />,
  kilometrage: <Truck className="w-4 h-4" />,
  source: <FileText className="w-4 h-4" />,
  confirmation: <CheckCircle className="w-4 h-4" />,
};

export default function VoiceDeclarationAgent({ currentUser, onDeclarationCreated }: VoiceDeclarationAgentProps) {
  const [sessionId, setSessionId] = useState<string>("");
  const [step, setStep] = useState(0);
  const [field, setField] = useState("greeting");
  const fieldRef = useRef(field);
  const [questionDarija, setQuestionDarija] = useState("");
  const [questionFrancais, setQuestionFrancais] = useState("");
  const [questionArabic, setQuestionArabic] = useState("");
  const [formData, setFormData] = useState<Record<string, string>>({});
  const [choices, setChoices] = useState<DarijaChoice[]>([]);
  const [chatHistory, setChatHistory] = useState<ChatMsg[]>([]);
  const [listening, setListening] = useState(false);
  const [speaking, setSpeaking] = useState(false);
  const [loading, setLoading] = useState(false);
  const [done, setDone] = useState(false);
  const doneRef = useRef(done);
  const [declarationId, setDeclarationId] = useState<number | null>(null);
  const [declarationCreated, setDeclarationCreated] = useState(false);
  const [retry, setRetry] = useState(false);
  const [retryMsg, setRetryMsg] = useState("");
  const [cancelled, setCancelled] = useState(false);
  const [muted, setMuted] = useState(false);
  const mutedRef = useRef(muted);

  const [inputText, setInputText] = useState("");
  const [interimText, setInterimText] = useState("");
  const [sttError, setSttError] = useState("");
  const [pendingConfirm, setPendingConfirm] = useState<string | null>(null);
  const [listeningTimer, setListeningTimer] = useState(0);
  const listeningTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const [showPlateCorrection, setShowPlateCorrection] = useState(false);
  const [overheardPlate, setOverheardPlate] = useState("");

  const sttErrorCountRef = useRef(0);
  const sttLangRef = useRef("ar-SA");

  const recognitionRef = useRef<any>(null);
  const chatEndRef = useRef<HTMLDivElement>(null);
  const lastSpokenRef = useRef("");

  const startListeningRef = useRef<() => void>(() => {});
  const handleUserResponseRef = useRef<(text: string) => Promise<void>>(async () => {});
  const audioLevelRef = useRef(0);
  const [audioLevel, setAudioLevel] = useState(0);
  const silenceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const accumulatedTextRef = useRef("");
  const [ttsUrl, setTtsUrl] = useState("");
  const [ttsKey, setTtsKey] = useState(0);
  const [ttsBlocked, setTtsBlocked] = useState(false);
  const audioRef = useRef<HTMLAudioElement>(null);
  const stopTtsRef = useRef(false);
  const playTtsRequestRef = useRef<(() => void) | null>(null);

  type AgentState = 'IDLE' | 'IA_PARLE' | 'ECOUTE' | 'TRANSCRIPTION' | 'IA_REFLECHIT';
  const [agentState, setAgentState] = useState<AgentState>('IDLE');

  const vadTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const lastResultTimeRef = useRef(0);

  const vehiculesDataRef = useRef<any[]>([]);
  const [vehiculeChoices, setVehiculeChoices] = useState<DarijaChoice[]>([]);

  const fetchVehicules = useCallback(async () => {
    try {
      const chauffeurId = currentUser?.id || 0;
      let list: any[] = [];
      if (chauffeurId > 0) {
        try {
          const res = await axios.get(`${API}/api/vehicules/chauffeur/${chauffeurId}`);
          list = Array.isArray(res.data) ? res.data : [];
        } catch { }
      }
      if (list.length === 0) {
        const res = await axios.get(`${API}/api/vehicules`);
        list = Array.isArray(res.data) ? res.data : [];
      }
      vehiculesDataRef.current = list;
      const choix: DarijaChoice[] = list.map((v: any, i: number) => ({
        id: i + 1,
        label_fr: `${v.immatriculation || ""} — ${v.marque || ""} ${v.modele || ""}`.trim(),
        label_darija: v.immatriculation || "",
        label_arabic: v.immatriculation || "",
      }));
      setVehiculeChoices(choix);
    } catch { vehiculesDataRef.current = []; setVehiculeChoices([]); }
  }, [currentUser?.id]);

  const stopTts = useCallback(() => {
    stopTtsRef.current = true;
    setSpeaking(false);
    if (audioRef.current) { try { audioRef.current.pause(); audioRef.current.currentTime = 0; } catch {} }
  }, []);

  const handleAudioEnded = useCallback(() => {
    setSpeaking(false);
    if (stopTtsRef.current) return;
    if (!muted && !done) {
      setAgentState('ECOUTE');
      startListeningRef.current();
    }
  }, [muted, done]);

  const handleAudioCanPlay = useCallback(() => {
    if (!audioRef.current) return;
    audioRef.current.play().catch((err) => {
      if (err.name === "NotAllowedError") {
        setTtsBlocked(true);
        playTtsRequestRef.current = () => {
          setTtsBlocked(false);
          audioRef.current?.play().catch(() => {});
        };
      }
    });
  }, []);

  useEffect(() => {
    if (ttsUrl && audioRef.current) {
      audioRef.current.load();
    }
  }, [ttsUrl, ttsKey]);

  const playTts = useCallback((text: string) => {
    if (!text || muted) return;
    stopTtsRef.current = false;
    const params = new URLSearchParams({ text, voice: "ar-MA-JamalNeural", rate: "-5%" });
    setTtsUrl(`${TTS_API}/api/tts/speak?${params.toString()}`);
    setTtsKey(k => k + 1);
    setSpeaking(true);
    setTtsBlocked(false);
  }, [muted]);

  const ttsRetryCountRef = useRef(0);
  const handleAudioError = useCallback(() => {
    setSpeaking(false);
    if (stopTtsRef.current) return;
    ttsRetryCountRef.current++;
    if (ttsRetryCountRef.current <= 1) {
      setTimeout(() => setTtsKey(k => k + 1), 2000);
    } else {
      ttsRetryCountRef.current = 0;
      if (!doneRef.current && !mutedRef.current) {
        setAgentState('ECOUTE');
        startListeningRef.current();
      }
    }
  }, []);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [chatHistory]);

  useEffect(() => {
    let ttsText = questionArabic || "";
    if (!ttsText && questionDarija) {
      ttsText = transliterateDarija(questionDarija);
    }
    const isVeh = (field === "immatriculation" || field === "vehicule") && vehiculeChoices.length > 0;
    if (isVeh) {
      ttsText = "\u0627\u062E\u062A\u0631 \u0633\u064A\u0627\u0631\u062A\u0643: \u0642\u0644 \u0627\u0644\u0631\u0642\u0645";
    }
    const choicesText = choices.length > 0
      ? ". " + choices.map((c, i) => `${i + 1}... ${c.label_arabic || c.label_fr}`).join(" - ")
      : "";
    const vChoicesText = isVeh
      ? ". " + vehiculeChoices.map(vc => `${vc.id}... ${vc.label_darija}`).join(" - ")
      : "";
    const fullText = ttsText + choicesText + vChoicesText;
    if (fullText && fullText !== lastSpokenRef.current) {
      lastSpokenRef.current = fullText;
      if (!muted && !done) {
        setAgentState('IA_PARLE');
        playTts(fullText);
      }
    }
  }, [questionArabic, questionDarija, questionFrancais, choices, vehiculeChoices, field, muted, done, playTts]);

  const startListening = useCallback(() => {
    if (!Recognition) { setSttError("Reconnaissance vocale non support\u00E9e par ce navigateur."); return; }
    if (recognitionRef.current) {
      try { recognitionRef.current.abort(); } catch {}
    }
    setSttError("");
    setInterimText("");
    setAgentState('ECOUTE');

    if (vadTimerRef.current) { clearInterval(vadTimerRef.current); vadTimerRef.current = null; }
    lastResultTimeRef.current = Date.now();
    vadTimerRef.current = setInterval(() => {
      if (Date.now() - lastResultTimeRef.current > 1000) {
        const text = accumulatedTextRef.current.trim();
        if (text.length > 0) {
          if (vadTimerRef.current) { clearInterval(vadTimerRef.current); vadTimerRef.current = null; }
          if (recognitionRef.current) {
            try { recognitionRef.current.abort(); } catch {}
            recognitionRef.current = null;
          }
          setListening(false);
          accumulatedTextRef.current = "";
          const confirmFields = ['kilometrage'];
          if (confirmFields.includes(fieldRef.current)) {
            setPendingConfirm(text);
            stopTtsRef.current = true;
            if (!mutedRef.current) {
              const confirmTts = `\u0642\u0644\u062A: ${text}. \u0647\u0644 \u0647\u0630\u0627 \u0635\u062D\u064A\u062D?`;
              const params = new URLSearchParams({ text: confirmTts, voice: "ar-MA-JamalNeural", rate: "-5%" });
              setTtsUrl(`${TTS_API}/api/tts/speak?${params.toString()}`);
              setTtsKey(k => k + 1);
            }
          } else {
            setAgentState('IA_REFLECHIT');
            handleUserResponseRef.current(text);
          }
        } else {
          lastResultTimeRef.current = Date.now();
        }
      }
    }, 250);

    const lang = sttLangRef.current;
    const recog = new Recognition();
    recog.lang = lang;
    recog.continuous = true;
    recog.interimResults = true;
    recog.maxAlternatives = 10;

    recog.onstart = () => {
      console.log("[STT] started lang=" + lang);
      setListening(true);
      setSttError("");
      setListeningTimer(0);
      if (listeningTimerRef.current) clearInterval(listeningTimerRef.current);
      listeningTimerRef.current = setInterval(() => setListeningTimer(t => t + 1), 1000);
    };
    recog.onend = () => {
      console.log("[STT] ended");
      setListening(false);
    };
    recog.onerror = (e: any) => {
      console.warn("[STT] Error:", e.error || e);
      setListening(false);
      if (e.error === "aborted") return;
      sttErrorCountRef.current++;
      if (e.error === "not-allowed") {
        if (vadTimerRef.current) { clearInterval(vadTimerRef.current); vadTimerRef.current = null; }
        setSttError("Acc\u00E8s au micro refus\u00E9. Autorisez le micro dans les param\u00E8tres du navigateur.");
        return;
      }
      if (sttErrorCountRef.current >= 3) {
        if (vadTimerRef.current) { clearInterval(vadTimerRef.current); vadTimerRef.current = null; }
        const fallbacks: Record<string, string> = { "fr-FR": "fr", "fr": "ar-MA", "ar-MA": "ar", "ar-SA": "fr-FR" };
        const next = fallbacks[sttLangRef.current];
        if (next) {
          setSttError(`Langue "${sttLangRef.current}" indisponible. Tentative avec "${next}"...`);
          sttLangRef.current = next;
          sttErrorCountRef.current = 0;
          startListeningRef.current();
        } else {
          const edgeHint = isEdge ? "\n\U0001F4A1 Edge : Param\u00E8tres Windows > Confidentialit\u00E9 > Reconnaissance vocale en ligne > Activer\n\U0001F4A1 Ou utilisez Chrome" : "";
          setSttError(`Reconnaissance vocale indisponible (${e.error || "inconnu"}).${edgeHint}\n\u2714\uFE0F Utilisez les boutons ou tapez votre r\u00E9ponse ci-dessous.`);
        }
        return;
      }
      const errMsg = e.error === "no-speech" ? "Aucun son d\u00E9tect\u00E9. Parlez dans le micro."
        : `Erreur micro (${e.error || "inconnu"})`;
      setSttError(errMsg);
    };

    recog.onresult = (event: any) => {
      sttErrorCountRef.current = 0;
      setSttError("");
      lastResultTimeRef.current = Date.now();
      let newFinal = "";
      let bestConfidence = 0;
      let lastInterim = "";
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const result = event.results[i];
        if (result.isFinal) {
          for (let j = 0; j < result.length; j++) {
            const alt = result[j];
            if (alt.confidence > bestConfidence || !newFinal) {
              bestConfidence = alt.confidence || 0;
              newFinal = alt.transcript;
            }
          }
        } else if (result[0]?.transcript) {
          lastInterim = result[0].transcript;
          const level = Math.min(1, Math.abs(lastInterim.length * 0.03));
          setAudioLevel(level);
        }
      }
      if (lastInterim) {
        setInterimText(lastInterim);
      }
      if (newFinal && newFinal.trim().length > 0) {
        accumulatedTextRef.current += " " + newFinal.trim();
        const acc = accumulatedTextRef.current.trim();
        setInterimText(acc);
      }
    };

    try { recog.start(); recognitionRef.current = recog; }
    catch (err: any) {
      console.error("[STT] Start error:", err);
      setSttError("Impossible de d\u00E9marrer le micro. V\u00E9rifiez les permissions.");
    }
  }, []);

  startListeningRef.current = startListening;

  const stopListening = useCallback(() => {
    if (vadTimerRef.current) { clearInterval(vadTimerRef.current); vadTimerRef.current = null; }
    if (silenceTimerRef.current) { clearTimeout(silenceTimerRef.current); silenceTimerRef.current = null; }
    if (listeningTimerRef.current) { clearInterval(listeningTimerRef.current); listeningTimerRef.current = null; }
    accumulatedTextRef.current = "";
    if (recognitionRef.current) {
      try { recognitionRef.current.stop(); } catch {}
      recognitionRef.current = null;
    }
    setListening(false);
  }, []);

  const matchVehiculeByNumber = useCallback((input: string): string | null => {
    if (vehiculeChoices.length === 0) return null;
    const t = input.trim().toLowerCase();
    const direct = parseInt(t);
    if (!isNaN(direct) && direct >= 1 && direct <= vehiculeChoices.length) return vehiculeChoices[direct - 1].label_darija;
    const norm = normalizeImmatriculation(t);
    const digits = norm.replace(/\D/g, '');
    const parsed = parseInt(digits);
    if (!isNaN(parsed) && parsed >= 1 && parsed <= vehiculeChoices.length) return vehiculeChoices[parsed - 1].label_darija;
    const cleanInput = norm.replace(/[^A-Z0-9]/gi, '').toUpperCase();
    for (const vc of vehiculeChoices) {
      const cleanPlate = vc.label_darija.replace(/[^A-Z0-9]/gi, '').toUpperCase();
      if (cleanInput === cleanPlate) return vc.label_darija;
      if (cleanPlate.startsWith(cleanInput)) return vc.label_darija;
      if (cleanInput.includes(cleanPlate) || cleanPlate.includes(cleanInput)) return vc.label_darija;
    }
    return null;
  }, [vehiculeChoices]);

  const handleUserResponse = async (text: string) => {
    if (loading || done) return;
    if (vadTimerRef.current) { clearInterval(vadTimerRef.current); vadTimerRef.current = null; }
    if (silenceTimerRef.current) { clearTimeout(silenceTimerRef.current); silenceTimerRef.current = null; }
    accumulatedTextRef.current = "";
    setAudioLevel(0);
    setInterimText("");
    setSttError("");
    sttErrorCountRef.current = 0;
    stopTts();
    stopListening();
    setAgentState('IA_REFLECHIT');

    let processedText = text;
    if (field === "immatriculation" || field === "vehicule") {
      const matched = matchVehiculeByNumber(text);
      if (matched) {
        processedText = matched;
      } else {
        const normalized = normalizeImmatriculation(text);
        if (/^\d+/.test(normalized)) {
          processedText = normalized;
        } else {
          setOverheardPlate(normalized || text);
          setShowPlateCorrection(true);
          if (!muted) {
            const reprompt = questionArabic || "\u0627\u0644\u0631\u062C\u0627\u0621 \u0625\u0639\u0627\u062F\u0629 \u0631\u0642\u0645 \u0627\u0644\u062A\u0645\u0627\u062B\u064A\u0644 \u0623\u0648 \u0627\u062E\u062A\u0631 \u0645\u0646 \u0627\u0644\u0642\u0627\u0626\u0645\u0629";
            setAgentState('IA_PARLE');
            playTts(reprompt);
          }
          return;
        }
      }
    }

    setChatHistory(prev => [...prev, { type: "user", text: processedText, timestamp: new Date() }]);
    setLoading(true);

    try {
      const res = await axios.post<VoiceAgentResponse>(`${API}/api/voice-agent/respond`, {
        sessionId,
        step,
        response: processedText,
      });

      const data = res.data;

      if (data.error) {
        setChatHistory(prev => [...prev, { type: "ai", text: data.error || "Erreur", timestamp: new Date() }]);
        setLoading(false);
        return;
      }

      if (data.cancelled) {
        setAgentState('IDLE');
        setCancelled(true);
        setDone(true); doneRef.current = true;
        setChatHistory(prev => [...prev, { type: "ai", text: data.questionDarija || data.questionFrancais || "D\u00E9claration annul\u00E9e", textFr: data.questionFrancais, timestamp: new Date() }]);
        if (!muted) {
          const cancelText = data.questionArabic || transliterateDarija(data.questionDarija || "") || data.questionFrancais; if (cancelText) playTts(cancelText);
        }
        setLoading(false);
        return;
      }

      if (data.declarationCreated && data.declarationId) {
        setAgentState('IDLE');
        setDeclarationId(data.declarationId);
        setDeclarationCreated(true);
        setDone(true); doneRef.current = true;
        setFormData(data.formData || {});
        setChatHistory(prev => [...prev, { type: "ai", text: data.questionDarija || data.questionFrancais || "D\u00E9claration enregistr\u00E9e", textFr: data.questionFrancais, timestamp: new Date() }]);
        if (onDeclarationCreated) onDeclarationCreated(data.declaration || data.formData);
        if (!muted) {
          const successText = data.questionArabic || transliterateDarija(data.questionDarija || "") || data.questionFrancais; if (successText) playTts(successText);
        }
        setLoading(false);
        return;
      }

      if (data.retry) {
        setRetry(true);
        setRetryMsg(data.retryMessage || "3awed 9ol liya...");
        setChoices(data.choices || []);
        setQuestionArabic(data.questionArabic || "");
        setChatHistory(prev => [...prev, { type: "ai", text: data.retryMessage || data.questionDarija || "Ma fhamtch, 3awed goul", textFr: data.retryMessageFr || data.questionFrancais, timestamp: new Date() }]);
      } else {
        setRetry(false);
        setRetryMsg("");
        setStep(data.step || step + 1);
        setField(data.field || ""); fieldRef.current = data.field || "";
        setQuestionDarija(data.questionDarija || "");
        setQuestionFrancais(data.questionFrancais || "");
        setQuestionArabic(data.questionArabic || "");
        setChoices(data.choices || []);
        setFormData(data.formData || formData);
        setChatHistory(prev => [...prev, { type: "ai", text: data.questionDarija || data.questionFrancais || "Question suivante", textFr: data.questionFrancais, timestamp: new Date() }]);
      }

      if (data.done) { setDone(true); doneRef.current = true; }
    } catch (err: any) {
      setChatHistory(prev => [...prev, { type: "ai", text: "Mochkil f connexion. 3awed men b3d.", textFr: "Erreur de connexion. R\u00E9essayez.", timestamp: new Date() }]);
    } finally {
      setLoading(false);
    }
  };

  handleUserResponseRef.current = handleUserResponse;

  const startSession = async () => {
    stopTts();
    lastSpokenRef.current = "";
    setLoading(true);
    setChatHistory([]);
    setDone(false); doneRef.current = false;
    setDeclarationCreated(false);
    setCancelled(false);
    setDeclarationId(null);
    setFormData({});
    setSttError("");
    sttErrorCountRef.current = 0;
    sttLangRef.current = "ar-SA";

    try {
      const res = await axios.post<VoiceAgentResponse>(`${API}/api/voice-agent/start`, {
        chauffeurId: currentUser?.id || 0,
        chauffeurNom: currentUser?.name || currentUser?.firstname || "Chauffeur",
        chauffeurMatricule: currentUser?.matricule || "",
      });

      const data = res.data;
      setSessionId(data.sessionId || "");
      setStep(data.step || 1);
      setField(data.field || "greeting"); fieldRef.current = data.field || "greeting";
      setQuestionDarija(data.questionDarija || "");
      setQuestionFrancais(data.questionFrancais || "");
      setQuestionArabic(data.questionArabic || "");
      setChoices(data.choices || []);
      setChatHistory([{ type: "ai", text: data.questionDarija || data.questionFrancais || "Salam, nbdaou?", textFr: data.questionFrancais, timestamp: new Date() }]);
      setAgentState('IA_PARLE');
    } catch {
      setChatHistory([{ type: "ai", text: "Mochkil f connexion. 3awed t3awed.", textFr: "Erreur de connexion. R\u00E9essayez.", timestamp: new Date() }]);
    } finally {
      setLoading(false);
    }
  };

  const selectChoice = (choice: DarijaChoice) => {
    setPendingConfirm(null);
    handleUserResponse(choice.label_darija);
  };

  const sendTextInput = () => {
    if (!inputText.trim()) return;
    handleUserResponse(inputText.trim());
    setInputText("");
  };

  const progressPercent = step > 0 ? Math.min(Math.round((step / 12) * 100), 100) : 0;

  useEffect(() => { mutedRef.current = muted; }, [muted]);
  useEffect(() => { doneRef.current = done; }, [done]);
  useEffect(() => {
    if (muted) { stopTts(); }
  }, [muted, stopTts]);

  useEffect(() => {
    if ((field === "immatriculation" || field === "vehicule") && sessionId && !done) {
      fetchVehicules();
    }
  }, [field, step, sessionId, done, fetchVehicules]);

  useEffect(() => {
    return () => {
      if (vadTimerRef.current) clearInterval(vadTimerRef.current);
      if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
    };
  }, []);

  const handleContainerClick = useCallback(() => {
    if (playTtsRequestRef.current) {
      playTtsRequestRef.current();
      playTtsRequestRef.current = null;
    }
  }, []);

  return (
    <div className="max-w-2xl mx-auto p-4 space-y-4" onClick={handleContainerClick}>
      {ttsUrl && (
        <audio key={ttsKey} ref={audioRef} src={ttsUrl} preload="auto" hidden
          onCanPlay={handleAudioCanPlay}
          onEnded={handleAudioEnded}
          onError={handleAudioError} />
      )}
      {ttsBlocked && (
        <div className="fixed bottom-4 left-1/2 -translate-x-1/2 z-50 bg-yellow-500 text-black px-4 py-2 rounded-full shadow-lg text-sm font-bold animate-pulse cursor-pointer">
          Cliquez pour activer la voix
        </div>
      )}
      <div className="bg-gradient-to-r from-blue-600 to-indigo-700 rounded-2xl p-4 text-white shadow-lg">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-white/20 rounded-xl flex items-center justify-center">
              <Mic className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-lg font-bold">{"Agent IA Vocal - \u0627\u0644\u0652\u0648\u0650\u0643\u0650\u064A\u0644 \u0627\u0644\u0635\u0651\u0648\u062A\u064A \u0627\u0644\u0630\u0651\u0643\u064A"}</h1>
              <p className="text-xs text-blue-100">{"D\u00E9claration par la voix \u2014 3ammar b sawtk!"}</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button onClick={() => setMuted(!muted)} className="p-2 rounded-lg hover:bg-white/20 transition-colors" title={muted ? "Activer le son" : "D\u00E9sactiver le son"}>
              {muted ? <VolumeX className="w-5 h-5" /> : <Volume2 className="w-5 h-5" />}
            </button>
          </div>
        </div>

        {!done && step > 0 && (
          <div className="mt-3">
            <div className="flex items-center justify-between text-xs text-blue-100 mb-1">
              <span>{"\u00C9tape "}{step}/12</span>
              <span>{progressPercent}%</span>
            </div>
            <div className="w-full bg-white/20 rounded-full h-2">
              <div className="bg-white rounded-full h-2 transition-all duration-500" style={{ width: `${progressPercent}%` }} />
            </div>
          </div>
        )}
      </div>

      {!sessionId && !done && (
        <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-lg border border-gray-200 dark:border-gray-700 p-8 text-center">
          {!sttSupported && (
            <div className="mb-4 bg-amber-50 dark:bg-amber-900/30 border border-amber-200 dark:border-amber-700 rounded-xl p-3 text-sm text-amber-700 dark:text-amber-300">
              {"\u26A0\uFE0F Votre navigateur ne supporte pas la reconnaissance vocale. Utilisez Chrome ou Edge."}
            </div>
          )}
          {isEdge && sttSupported && (
            <div className="mb-4 bg-blue-50 dark:bg-blue-900/30 border border-blue-200 dark:border-blue-700 rounded-xl p-3 text-xs text-blue-600 dark:text-blue-300">
              {"Edge d\u00E9tect\u00E9 \u2014 la reconnaissance vocale fonctionne en Fran\u00E7ais. Parlez normalement."}
            </div>
          )}
          <div className="w-20 h-20 mx-auto bg-blue-50 dark:bg-blue-900/30 rounded-full flex items-center justify-center mb-4">
            <Mic className="w-10 h-10 text-blue-500" />
          </div>
          <h2 className="text-xl font-bold text-gray-800 dark:text-white mb-2">{"D\u00E9claration Vocale"}</h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mb-2">{"Agent IA \u0628\u0627\u0644\u062F\u0627\u0631\u062C\u0629 \u2014 3ammar l'd\u00E9claration b sawtk bla ma tekteb walo"}</p>
          <p className="text-xs text-gray-600 dark:text-gray-400 mb-6">{"L'agent IA vous guidera \u00E9tape par \u00E9tape en Darija marocaine"}</p>

          <div className="space-y-2 mb-6 text-left bg-gray-50 dark:bg-gray-900 rounded-xl p-4">
            <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-300"><Truck className="w-4 h-4 text-blue-500" /> {"Identifier le v\u00E9hicule"}</div>
            <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-300"><Wrench className="w-4 h-4 text-orange-500" /> {"D\u00E9crire le type de panne"}</div>
            <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-300"><MapPin className="w-4 h-4 text-green-500" /> {"Indiquer le lieu"}</div>
            <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-300"><CheckCircle className="w-4 h-4 text-emerald-500" /> {"Confirmer et valider"}</div>
          </div>

          <button onClick={startSession} disabled={loading}
            className="px-8 py-3 bg-gradient-to-r from-blue-500 to-indigo-600 text-white rounded-xl font-bold text-base shadow-lg hover:scale-[1.02] transition-all disabled:opacity-50 flex items-center gap-2 mx-auto">
            {loading ? <Loader2 className="w-5 h-5 animate-spin" /> : <Mic className="w-5 h-5" />}
            {"Commencer la D\u00E9claration Vocale"}
          </button>
        </div>
      )}

      {sessionId && !done && (
        <div className="space-y-3">
          {questionDarija && (
            <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-2xl p-4">
              <div className="flex items-start gap-3">
                <div className="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center shrink-0">
                  <Bot className="w-5 h-5 text-white" />
                </div>
                <div className="flex-1">
                  <p className="text-base font-bold text-blue-800 dark:text-blue-200" dir="rtl">{questionDarija}</p>
                  {questionFrancais && questionFrancais !== questionDarija && (
                    <p className="text-sm text-blue-600 dark:text-blue-300 mt-1">{questionFrancais}</p>
                  )}
                  {retry && retryMsg && (
                    <p className="text-xs text-amber-600 mt-1 flex items-center gap-1">
                      <AlertCircle className="w-3 h-3" /> {retryMsg}
                    </p>
                  )}
                </div>
                <div className="flex flex-col items-center gap-1">
                  <button onClick={() => { const t = questionArabic || transliterateDarija(questionDarija || "") || questionFrancais; if (t) playTts(t); }}
                    className="p-1.5 rounded-lg text-blue-400 hover:bg-blue-100 dark:hover:bg-blue-900/40 transition-colors"
                    title={"Rejouer l'audio"}>
                    {speaking ? <Loader2 className="w-4 h-4 animate-spin" /> : <Volume2 className="w-4 h-4" />}
                  </button>
                  <div className="text-blue-400">{STEP_ICONS[field] || <MessageCircle className="w-4 h-4" />}</div>
                </div>
              </div>
            </div>
          )}

          {(field === "immatriculation" || field === "vehicule") && vehiculeChoices.length > 0 && (
            <div className="space-y-1">
              <p className="text-xs font-bold text-gray-600 dark:text-gray-300 text-center">
                {"Choisissez votre v\u00E9hicule (dites le num\u00E9ro ou cliquez) \u2193"}
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {vehiculeChoices.map(vc => (
                  <button key={vc.id} onClick={() => selectChoice(vc)} disabled={loading}
                    className="flex items-center gap-3 px-4 py-3 bg-white dark:bg-gray-800 border-2 border-emerald-200 dark:border-emerald-700 rounded-xl text-sm font-medium text-gray-700 dark:text-gray-200 hover:border-emerald-400 hover:bg-emerald-50 dark:hover:bg-emerald-900/30 hover:shadow-md transition-all text-left disabled:opacity-50">
                    <span className="flex-shrink-0 w-8 h-8 rounded-full bg-emerald-500 text-white flex items-center justify-center text-sm font-bold shadow-sm">{vc.id}</span>
                    <div className="flex flex-col">
                      <span className="font-mono font-bold text-gray-800 dark:text-gray-100 text-base">{vc.label_darija}</span>
                      <span className="text-[10px] text-gray-500 dark:text-gray-400">{vc.label_fr}</span>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          )}
          {choices.length > 0 && !((field === "immatriculation" || field === "vehicule") && vehiculeChoices.length > 0) && (
            <div className="space-y-1">
              <p className="text-[10px] text-gray-600 dark:text-gray-400 text-center">
                {"\u2191 Choisis une option (parle ou clique) \u2191"}
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {choices.map(choice => (
                  <button key={choice.id} onClick={() => selectChoice(choice)} disabled={loading}
                    className="flex items-center gap-3 px-4 py-3 bg-white dark:bg-gray-800 border-2 border-gray-200 dark:border-gray-600 rounded-xl text-sm font-medium text-gray-700 dark:text-gray-200 hover:border-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/30 hover:shadow-md transition-all text-left disabled:opacity-50 disabled:cursor-wait">
                    <span className="flex-shrink-0 w-8 h-8 rounded-full bg-blue-500 text-white flex items-center justify-center text-sm font-bold shadow-sm">{choice.id}</span>
                    <div className="flex flex-col">
                      <span className="text-xs text-gray-500 dark:text-gray-400">{choice.label_fr}</span>
                      <span dir="rtl" className="font-bold text-gray-800 dark:text-gray-100 text-base">{choice.label_arabic}</span>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          )}

          {pendingConfirm && (
            <div className="bg-amber-50 dark:bg-amber-900/20 border-2 border-amber-200 dark:border-amber-700 rounded-2xl p-4 text-center space-y-3">
              <p className="text-xs text-amber-600 dark:text-amber-400 font-semibold">{"J\u2019ai entendu :"}</p>
              <p className="text-lg font-bold text-gray-800 dark:text-white" dir={/[\u0600-\u06FF]/.test(pendingConfirm) ? "rtl" : "ltr"}>{pendingConfirm!}</p>
              <p className="text-[10px] text-amber-500">C\u2019est correct ?</p>
              <div className="flex items-center justify-center gap-3">
                <button onClick={() => { handleUserResponseRef.current(pendingConfirm!); setPendingConfirm(null); }}
                  disabled={loading}
                  className="px-5 py-2 bg-green-500 hover:bg-green-600 text-white rounded-xl font-bold text-sm flex items-center gap-1.5 transition-all disabled:opacity-50">
                  <CheckCircle className="w-4 h-4" /> Oui, envoyer
                </button>
                <button onClick={() => { setPendingConfirm(null); setInterimText(""); setAgentState('ECOUTE'); startListeningRef.current(); }}
                  className="px-5 py-2 bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 rounded-xl font-bold text-sm flex items-center gap-1.5 transition-all">
                  <Mic className="w-4 h-4" /> Re-parler
                </button>
                <button onClick={() => setPendingConfirm(null)}
                  className="px-5 py-2 bg-transparent border border-gray-300 dark:border-gray-600 text-gray-500 rounded-xl text-sm hover:bg-gray-50 dark:hover:bg-gray-800 transition-all">
                  Annuler
                </button>
              </div>
            </div>
          )}

          {showPlateCorrection && choices.length > 0 && (
            <div className="bg-red-50 dark:bg-red-900/20 border-2 border-red-300 dark:border-red-700 rounded-2xl p-4 space-y-3">
              <div className="text-center">
                <p className="text-xs text-red-500 font-semibold">{"\u26A0\uFE0F Format plaque non reconnu"}</p>
                <p className="text-sm text-red-600 dark:text-red-400 mt-1">
                  {"Vous avez dit : "}<span className="font-bold">{overheardPlate}</span>
                </p>
                <p className="text-[10px] text-red-400 mt-1">R\u00E9p\u00E9tez le num\u00E9ro ou choisissez votre v\u00E9hicule :</p>
              </div>
              <div className="grid grid-cols-1 gap-2">
                {choices.map(choice => (
                  <button key={choice.id} onClick={() => { setShowPlateCorrection(false); handleUserResponse(choice.label_arabic || choice.label_fr); }} disabled={loading}
                    className="flex items-center gap-3 px-4 py-3 bg-white dark:bg-gray-800 border-2 border-red-200 dark:border-red-600 rounded-xl text-sm font-medium text-gray-700 dark:text-gray-200 hover:border-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/30 transition-all text-left">
                    <span className="flex-shrink-0 w-8 h-8 rounded-full bg-red-500 text-white flex items-center justify-center text-sm font-bold">{choice.id}</span>
                    <div className="flex flex-col">
                      <span className="text-xs text-gray-500 dark:text-gray-400">{choice.label_fr}</span>
                      <span dir="rtl" className="font-bold text-gray-800 dark:text-gray-100 text-base">{choice.label_arabic}</span>
                    </div>
                  </button>
                ))}
              </div>
              <div className="flex items-center justify-center gap-2">
                <button onClick={() => { setShowPlateCorrection(false); setAgentState('ECOUTE'); startListeningRef.current(); }}
                  className="px-4 py-2 bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 rounded-xl text-sm flex items-center gap-1.5 transition-all">
                  <Mic className="w-4 h-4" /> R\u00E9essayer
                </button>
                <button onClick={() => setShowPlateCorrection(false)}
                  className="px-4 py-2 bg-transparent border border-gray-300 dark:border-gray-600 text-gray-500 rounded-xl text-sm transition-all">
                  Annuler
                </button>
              </div>
            </div>
          )}
          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                if (pendingConfirm) { setPendingConfirm(null); setInterimText(""); }
                if (listening) stopListening();
                else if (agentState === 'IA_PARLE') { stopTts(); setAgentState('ECOUTE'); startListening(); }
                else { setAgentState('ECOUTE'); startListening(); }
              }}
              className={`w-14 h-14 rounded-full flex items-center justify-center shadow-lg transition-all duration-300 ${
                agentState === 'IA_PARLE' ? "bg-red-500 hover:bg-red-600" :
                listening ? "bg-blue-500 hover:bg-blue-600" :
                agentState === 'TRANSCRIPTION' || agentState === 'IA_REFLECHIT' ? "bg-gray-400" :
                "bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700"
              }`}
              disabled={loading || done}>
              {listening ? <Mic className="w-6 h-6 text-white" /> :
               agentState === 'IA_PARLE' ? <Volume2 className="w-6 h-6 text-white" /> :
               agentState === 'TRANSCRIPTION' || agentState === 'IA_REFLECHIT' ? <Loader2 className="w-6 h-6 text-white animate-spin" /> :
               <Mic className="w-6 h-6 text-white" />}
            </button>

            <div className="flex-1 relative">
              <input type="text" value={inputText} onChange={e => setInputText(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && sendTextInput()}
                placeholder={listening ? "\u0643\u0646\u0633\u0645\u0639\u0643... hdar daba" : "\u00C9crivez votre r\u00E9ponse ici..."}
                className="w-full px-4 py-3 border-2 border-gray-200 dark:border-gray-600 rounded-xl text-sm bg-white dark:bg-gray-800 text-gray-800 dark:text-white focus:border-blue-400 focus:outline-none"
                disabled={loading || done} />
            </div>

            <button onClick={sendTextInput} disabled={!inputText.trim() || loading}
              className="w-14 h-14 bg-blue-500 hover:bg-blue-600 text-white rounded-xl flex items-center justify-center disabled:opacity-50 transition-all">
              <Send className="w-5 h-5" />
            </button>
          </div>

          {sttError && (
            <div className="bg-red-50 dark:bg-red-900/30 border-2 border-red-200 dark:border-red-700 rounded-xl p-4 text-sm whitespace-pre-line">
              <p className="font-bold text-red-600 dark:text-red-300 mb-1">{"\u26A0\uFE0F "}Micro / STT</p>
              <p className="text-red-500 dark:text-red-400">{sttError}</p>
              <button onClick={() => { setSttError(""); sttErrorCountRef.current = 0; sttLangRef.current = "ar-SA"; setAgentState('ECOUTE'); startListeningRef.current(); }}
                className="mt-2 px-4 py-1.5 bg-red-500 hover:bg-red-600 text-white rounded-lg text-xs font-bold transition-all">
                R\u00E9essayer le micro 🎤
              </button>
            </div>
          )}
          {agentState === 'ECOUTE' && (
            <div className="text-center space-y-3 py-3 transition-all duration-300">
              <div className="flex items-center justify-center gap-3">
                <span className="text-lg font-bold text-gray-700 dark:text-gray-200">{"\u0643\u0646\u0633\u0645\u0639\u0643..."}</span>
              </div>
              {interimText ? (
                <div className="bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/30 dark:to-indigo-900/30 border-2 border-blue-200 dark:border-blue-700 rounded-2xl px-6 py-4 max-w-lg mx-auto shadow-inner">
                  <p className="text-xl font-bold text-gray-800 dark:text-gray-100 text-right leading-relaxed" dir="rtl">{interimText}</p>
                  <div className="flex items-center justify-center gap-0.5 h-4 mt-2">
                    {Array.from({ length: 24 }).map((_, i) => (
                      <div key={i} className="w-0.5 bg-blue-500 rounded-full transition-all duration-150"
                        style={{
                          height: `${interimText
                            ? Math.max(4, Math.min(20, audioLevel * 16 + Math.sin(i * 0.8 + Date.now() * 0.008) * 4))
                            : Math.max(3, Math.min(8, Math.sin(i * 0.5 + Date.now() * 0.003) * 3 + 5))}px`
                        }}
                      />
                    ))}
                  </div>
                </div>
              ) : (
                <div>
                  <div className="flex items-center justify-center gap-0.5 h-4 mb-2">
                    {Array.from({ length: 24 }).map((_, i) => (
                      <div key={i} className="w-0.5 bg-blue-300 rounded-full transition-all duration-300"
                        style={{ height: `${Math.max(2, Math.min(8, Math.sin(i * 0.5 + Date.now() * 0.003) * 3 + 5))}px` }}
                      />
                    ))}
                  </div>
                  <div className="text-sm text-gray-600 dark:text-gray-400">{"\u0646\u062A\u0638\u0631 \u0643\u0644\u0627\u0645\u0643..."}</div>
                </div>
              )}
              <div className="flex items-center justify-center gap-2 text-[10px] text-gray-600 dark:text-gray-400">
                <span className="font-mono">{listeningTimer}s</span>
                <span>● En \u00E9coute</span>
                <button onClick={() => {
                  stopListening();
                  sttLangRef.current = sttLangRef.current.startsWith("fr") ? "ar-MA" : "fr-FR";
                  sttErrorCountRef.current = 0;
                  startListeningRef.current();
                }} className="px-2 py-0.5 bg-white/10 rounded text-[10px] hover:bg-white/20 transition-colors">
                  ↔ {sttLangRef.current.startsWith("fr") ? "\u0627\u0644\u0639\u0631\u0628\u064A\u0629" : "FR"}
                </button>
              </div>
            </div>
          )}
          {agentState === 'IA_PARLE' && (
            <div className="text-center py-3 transition-all duration-300">
              <div className="flex items-center justify-center gap-0.5 h-8 mb-1">
                {Array.from({ length: 24 }).map((_, i) => (
                  <div key={i} className="w-0.5 bg-red-400 rounded-full transition-all duration-200"
                    style={{
                      height: `${Math.max(4, Math.min(24,
                        Math.sin(i * 0.6 + Date.now() * 0.005) * 10 + 14
                      ))}px`
                    }}
                  />
                ))}
              </div>
              <span className="text-xs text-red-500 font-medium">Agent parle...</span>
            </div>
          )}
          {agentState === 'IA_REFLECHIT' && (
            <div className="text-center py-3 transition-all duration-300">
              <div className="flex items-center justify-center gap-0.5 h-6 mb-1">
                {Array.from({ length: 8 }).map((_, i) => (
                  <div key={i} className="w-1 bg-amber-400 rounded-full transition-all duration-300"
                    style={{
                      height: `${Math.max(3, Math.min(16,
                        Math.sin(i * 1.2 + Date.now() * 0.004) * 6 + 10
                      ))}px`
                    }}
                  />
                ))}
              </div>
              <span className="text-xs text-amber-500">R\u00E9flexion...</span>
            </div>
          )}
          {agentState === 'TRANSCRIPTION' && interimText && (
            <div className="text-center py-2">
              <div className="bg-gray-100 dark:bg-gray-800 rounded-xl px-4 py-2 max-w-sm mx-auto">
                <p className="text-sm text-gray-500" dir={/[\u0600-\u06FF]/.test(interimText) ? "rtl" : "ltr"}>{interimText}</p>
              </div>
            </div>
          )}

          {chatHistory.length > 1 && (
            <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl p-3 max-h-60 overflow-y-auto space-y-2">
              {chatHistory.slice(-8).map((msg, i) => (
                <div key={i} className={`flex items-start gap-2 ${msg.type === "user" ? "justify-end" : ""}`}>
                  {msg.type === "ai" && (
                    <div className="w-7 h-7 bg-blue-100 dark:bg-blue-900/50 rounded-full flex items-center justify-center shrink-0">
                      <Bot className="w-3.5 h-3.5 text-blue-500" />
                    </div>
                  )}
                  <div className={`max-w-[80%] px-3 py-2 rounded-xl text-sm ${
                    msg.type === "user"
                      ? "bg-indigo-500 text-white rounded-br-none"
                      : "bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-200 rounded-bl-none"
                  }`} dir={msg.type === "ai" ? "rtl" : "ltr"}>
                    {msg.text}
                    {msg.textFr && msg.type === "ai" && (
                      <p className="text-xs mt-1 opacity-70" dir="ltr">{msg.textFr}</p>
                    )}
                  </div>
                  {msg.type === "user" && (
                    <div className="w-7 h-7 bg-indigo-500 rounded-full flex items-center justify-center shrink-0">
                      <User className="w-3.5 h-3.5 text-white" />
                    </div>
                  )}
                </div>
              ))}
              <div ref={chatEndRef} />
            </div>
          )}

          {Object.keys(formData).length > 0 && (
            <div className="bg-gray-50 dark:bg-gray-900 rounded-xl p-3">
              <p className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-2">{"Donn\u00E9es collect\u00E9es:"}</p>
              <div className="grid grid-cols-2 gap-1 text-xs">
                {Object.entries(formData).filter(([k, v]) => v && k !== "ready").map(([k, v]) => (
                  <div key={k} className="flex items-center gap-1">
                    <CheckCircle className="w-3 h-3 text-emerald-500" />
                    <span className="text-gray-600 dark:text-gray-300">{k}: <strong>{v}</strong></span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {declarationCreated && (
        <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-lg border-2 border-emerald-300 dark:border-emerald-700 p-6 text-center">
          <div className="w-16 h-16 mx-auto bg-emerald-100 dark:bg-emerald-900/30 rounded-full flex items-center justify-center mb-4">
            <CheckCircle className="w-8 h-8 text-emerald-500" />
          </div>
          <h2 className="text-xl font-bold text-emerald-700 dark:text-emerald-300 mb-2">{"D\u00E9claration Enregistr\u00E9e! \u2014 \u062A\u0645 \u0627\u0644\u062A\u0633\u062C\u064A\u0644!"}</h2>
          {declarationId && (
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-1">{"Num\u00E9ro: "}<strong className="text-gray-800 dark:text-white">INC-{new Date().getFullYear()}-{String(declarationId).padStart(6, '0')}</strong></p>
          )}
          <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">Hadchi kollo tssajjal m3a sawtk bla ma ktebti walo.</p>

          {Object.keys(formData).length > 0 && (
            <div className="text-left bg-gray-50 dark:bg-gray-900 rounded-xl p-4 mb-4">
              <h3 className="text-sm font-bold text-gray-700 dark:text-gray-300 mb-2">{"R\u00E9sum\u00E9:"}</h3>
              <div className="space-y-1">
                {Object.entries(formData).filter(([k, v]) => v && k !== "ready").map(([k, v]) => (
                  <div key={k} className="flex justify-between text-xs">
                    <span className="text-gray-500 dark:text-gray-400">{k}</span>
                    <span className="font-medium text-gray-800 dark:text-gray-200">{v}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          <button onClick={startSession}
            className="px-6 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-xl font-bold text-sm flex items-center gap-2 mx-auto">
            <RefreshCw className="w-4 h-4" /> {"Nouvelle D\u00E9claration"}
          </button>
        </div>
      )}

      {cancelled && (
        <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-lg border-2 border-amber-300 dark:border-amber-700 p-6 text-center">
          <div className="w-16 h-16 mx-auto bg-amber-100 dark:bg-amber-900/30 rounded-full flex items-center justify-center mb-4">
            <XCircle className="w-8 h-8 text-amber-500" />
          </div>
          <h2 className="text-xl font-bold text-amber-700 dark:text-amber-300 mb-2">{"D\u00E9claration Annul\u00E9e"}</h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">Machi mochkil! 3awed t3awed men birri3la l'boton.</p>
          <button onClick={startSession}
            className="px-6 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-xl font-bold text-sm flex items-center gap-2 mx-auto">
            <RefreshCw className="w-4 h-4" /> Recommencer
          </button>
        </div>
      )}
    </div>
  );
}
