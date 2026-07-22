import '../entities/customer_entity.dart';

abstract class CustomerRepository {
  Future<CustomerEntity?> lookupByPhone(String phone);
}
