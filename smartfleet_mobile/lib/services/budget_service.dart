import '../database/dao/budget_dao.dart';
import '../database/dao/sync_dao.dart';

class BudgetService {
  final BudgetDao _dao = BudgetDao();
  final SyncDao _syncDao = SyncDao();

  Future<List<Map<String, dynamic>>> getAll() => _dao.getAll();

  Future<Map<String, dynamic>?> getCurrent() => _dao.getCurrent();

  Future<Map<String, dynamic>?> getById(int id) => _dao.getById(id);

  Future<int> create(Map<String, dynamic> data) async {
    final id = await _dao.insert(data);
    await _syncDao.addToQueue('budget_trimestriel', 'INSERT', id,
        payload: data,);
    return id;
  }

  Future<int> update(int id, Map<String, dynamic> data) async {
    final result = await _dao.update(id, data);
    await _syncDao.addToQueue('budget_trimestriel', 'UPDATE', id,
        payload: data,);
    return result;
  }

  Future<void> recalculerUtilisation(int budgetId) =>
      _dao.recalculerUtilisation(budgetId);

  Future<List<Map<String, dynamic>>> getByProvider(int budgetId) =>
      _dao.getByProvider(budgetId);

  Future<List<Map<String, dynamic>>> getByType(int budgetId) =>
      _dao.getByType(budgetId);
}
