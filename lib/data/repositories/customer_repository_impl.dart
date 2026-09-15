import '../../core/constants/app_config.dart';
import '../../data/datasources/api_clients.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/repositories/customer_repository.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerApi _api;
  CustomerRepositoryImpl([CustomerApi? api]) : _api = api ?? CustomerApi();

  @override
  Future<CustomerEntity?> lookupByPhone(String phone) async {
    if (!AppConfig.hasBackendConfigured || phone.isEmpty) return null;
    return _api.lookupByPhone(phone);
  }
}
