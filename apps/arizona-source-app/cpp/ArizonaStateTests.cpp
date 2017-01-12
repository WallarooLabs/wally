#include "ArizonaState.hpp"

bool test_proceeds()
{
  Proceeds p1(1.0, 2.0, 3.0, 4.0, "");
  Proceeds p2(1.0, 2.0, 3.0, 4.0, "");

  return p1 == p2;
}

bool test_proceeds_add()
{
  Proceeds p1(1.0, 2.0, 3.0, 4.0, "");
  Proceeds p2(1.0, 2.0, 3.0, 4.0, "");
  Proceeds p3(2.0, 4.0, 6.0, 8.0, "");

  return p1.add(p2) == p3;
}

bool test_order()
{
  string order_id("o1");
  Order x(order_id, Side::Buy, 10, 50.0);
  Order y(order_id, Side::Buy, 10, 50.0);
  return x == y;
}

bool test_orders()
{
  Orders orders;
  string order_id1("o1");
  string order_id2("o2");
  orders.add_order(order_id1, Side::Buy, 10, 50.0);
  orders.add_order(order_id2, Side::Buy, 20, 70.0);
  Proceeds p1 = Proceeds(0.0, 0.0, 0.0, 1900.0, "");
  Proceeds p2 = orders.proceeds();
  return p1 == p2;
}

bool test_isin()
{
  string account_id("a1");
  Account account(account_id);
  string isin_id("i1");
  ISIN isin(isin_id);
  string order_id1("o1");
  string order_id2("o2");
  isin.add_order(order_id1, Side::Buy, 10, 50.0, &account);
  isin.add_order(order_id2, Side::Buy, 20, 70.0, &account);
  Proceeds p1 = Proceeds(0.0, 0.0, 0.0, 1900.0, isin_id);
  Proceeds p2 = isin.proceeds();
  return p1 == p2;
}

bool test_isins()
{
  string account_id("a1");
  Account account(account_id);
  ISINs isins;
  string isin_id("i1");
  ISIN isin(isin_id);
  string order_id1("o1");
  string order_id2("o2");
  isins.add_order(isin_id, order_id1, Side::Buy, 10, 50.0, &account);
  Proceeds p1 = Proceeds(0.0, 0.0, 0.0, 1900.0, isin_id);
  Proceeds p2 = isins.proceeds_with_order(isin_id, order_id2, Side::Buy, 20, 70.0);
  return p1 == p2;
}

bool test_isins_first_proceeds()
{
  ISINs isins;
  string isin_id("i1");
  ISIN isin(isin_id);
  string order_id1("o1");
  Proceeds p1 = Proceeds(0.0, 0.0, 0.0, 1400.0, isin_id);
  Proceeds p2 = isins.proceeds_with_order(isin_id, order_id1, Side::Buy, 20, 70.0);
  return p1 == p2;
}

bool test_account()
{
  string account_id("a1");
  Account account(account_id);
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  account.add_order(isin_id, order_id1, Side::Buy, 10, 50.0);
  account.add_order(isin_id, order_id2, Side::Buy, 20, 70.0);
  Proceeds p1 = Proceeds(0.0, 0.0, 0.0, 1900.0, isin_id);
  Proceeds p2 = account.proceeds_for_isin(isin_id);
  return p1 == p2;
}

bool test_accounts()
{
  Accounts accounts;
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  accounts.add_order(account_id, isin_id, order_id1, Side::Buy, 10, 50.0);
  Proceeds p1 = Proceeds(0.0, 0.0, 0.0, 1900.0, isin_id);
  Proceeds p2 = accounts.proceeds_with_order(account_id, isin_id, order_id2, Side::Buy, 20, 70.0);
  return p1 == p2;
}

bool test_accounts_first_proceeds()
{
  Accounts accounts;
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  Proceeds p1 = Proceeds(0.0, 0.0, 0.0, 1400.0, isin_id);
  Proceeds p2 = accounts.proceeds_with_order(account_id, isin_id, order_id1, Side::Buy, 20, 70.0);
  return p1 == p2;
}

bool test_client()
{
  string client_id("c1");
  Client client(client_id);
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  client.add_order(account_id, isin_id, order_id1, Side::Buy, 10, 50.0);
  client.add_order(account_id, isin_id, order_id2, Side::Buy, 20, 70.0);
  Proceeds p1 = Proceeds(0.0, 0.0, 0.0, 1900.0, isin_id);
  Proceeds p2 = client.proceeds_for_isin(account_id, isin_id);
  return p1 == p2;
}

bool test_clients()
{
  Clients clients;
  string client_id("c1");
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  clients.add_order(client_id, account_id, isin_id, order_id1, Side::Buy, 10, 50.0);
  Proceeds p1 = Proceeds(0.0, 0.0, 0.0, 1900.0, isin_id);
  Proceeds p2 = clients.proceeds_with_order(client_id, account_id, isin_id, order_id2, Side::Buy, 20, 70.0);
  return p1 == p2;
}

bool test_clients_first_proceeds()
{
  Clients clients;
  string client_id("c1");
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  Proceeds p1 = Proceeds(0.0, 0.0, 0.0, 1400.0, isin_id);
  Proceeds p2 = clients.proceeds_with_order(client_id, account_id, isin_id, order_id1, Side::Buy, 20, 70.0);
  return p1 == p2;
}

bool test_clients_cancel()
{
  Clients clients;
  string client_id("c1");
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  string order_id3("o3");
  Proceeds p1 = Proceeds(0.0, 0.0, 0.0, 3500.0, isin_id);
  clients.add_order(client_id, account_id, isin_id, order_id1, Side::Buy, 20, 70.0);
  clients.add_order(client_id, account_id, isin_id, order_id2, Side::Buy, 10, 70.0);
  clients.add_order(client_id, account_id, isin_id, order_id3, Side::Buy, 40, 70.0);
  clients.cancel_order(client_id, account_id, order_id1);
  Proceeds p2 = clients.proceeds_for_isin(client_id, account_id, isin_id);
  return p1 == p2;
}

bool test_clients_proceeds_with_cancel()
{
  Clients clients;
  string client_id("c1");
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  string order_id3("o3");
  Proceeds p1 = Proceeds(0.0, 0.0, 0.0, 3500.0, isin_id);
  clients.add_order(client_id, account_id, isin_id, order_id1, Side::Buy, 20, 70.0);
  clients.add_order(client_id, account_id, isin_id, order_id2, Side::Buy, 10, 70.0);
  clients.add_order(client_id, account_id, isin_id, order_id3, Side::Buy, 40, 70.0);
  Proceeds p2 = clients.proceeds_with_cancel(client_id, account_id, order_id1);
  return p1 == p2;
}

bool test_orders_with_executions()
{
  string isin_id("i1");
  ISIN isin(isin_id);
  Orders orders;
  string order_id1("o1");
  string order_id2("o2");
  string execution_id1("e1");
  string execution_id2("e2");
  orders.add_order(order_id1, Side::Buy, 2100, 12.50);
  orders.add_order(order_id2, Side::Sell, 1500, 12.0);
  orders.execute(order_id1, execution_id1, 500, 12.50, &isin);
  orders.execute(order_id2, execution_id2, 500, 12.00, &isin);
  Proceeds p1 = Proceeds(6000.0, 6250.0, 12000.0, 20000.0, "");
  Proceeds p2 = orders.proceeds();
  return p1 == p2;
}

bool test_isin_with_filled_order()
{
  string account_id("a1");
  Account account(account_id);
  string isin_id("i1");
  ISIN isin(isin_id);
  Orders orders;
  string order_id1("o1");
  string order_id2("o2");
  string execution_id1("e1");
  string execution_id2("e2");
  string execution_id3("e3");
  isin.add_order(order_id1, Side::Buy, 2100, 12.50, &account);
  isin.add_order(order_id2, Side::Sell, 1500, 12.0, &account);
  isin.execute(order_id1, execution_id1, 500, 12.50);
  isin.execute(order_id2, execution_id2, 500, 12.00);
  isin.execute(order_id2, execution_id3, 1000, 12.00);
  Proceeds p1 = Proceeds(18000.0, 6250.0, 0.0, 20000.0, isin_id);
  Proceeds p2 = isin.proceeds();
  return p1 == p2;
}

bool test_isin_with_cancel_partially_filled_orders()
{
  string account_id("a1");
  Account account(account_id);
  string isin_id("i1");
  ISIN isin(isin_id);
  string order_id1("o1");
  string order_id2("o2");
  string execution_id1("e1");
  string execution_id2("e2");
  string cancel_id1("c1");
  string cancel_id2("c2");
  isin.add_order(order_id1, Side::Buy, 2100, 12.50, &account);
  isin.add_order(order_id2, Side::Sell, 1500, 12.0, &account);
  isin.execute(order_id1, execution_id1, 500, 12.50);
  isin.execute(order_id2, execution_id2, 500, 12.00);
  isin.cancel_order(order_id1);
  isin.cancel_order(order_id2);
  Proceeds p1 = Proceeds(6000.0, 6250.0, 0.0, 0.0, isin_id);
  Proceeds p2 = isin.proceeds();
  return p1 == p2;
}

bool test_isins_with_cancel_partially_filled_orders()
{
  string account_id("a1");
  Account account(account_id);
  string isin_id("i1");
  ISINs isins;
  string order_id1("o1");
  string order_id2("o2");
  string execution_id1("e1");
  string execution_id2("e2");
  string cancel_id1("c1");
  string cancel_id2("c2");
  isins.add_order(isin_id, order_id1, Side::Buy, 2100, 12.50, &account);
  isins.add_order(isin_id, order_id2, Side::Sell, 1500, 12.0, &account);
  isins.execute(isin_id, order_id1, execution_id1, 500, 12.50);
  isins.execute(isin_id, order_id2, execution_id2, 500, 12.00);
  isins.cancel_order(isin_id, order_id1);
  isins.cancel_order(isin_id, order_id2);
  Proceeds p1 = Proceeds(6000.0, 6250.0, 0.0, 0.0, isin_id);
  Proceeds p2 = isins.proceeds_for_isin(isin_id);
  return p1 == p2;
}

bool test_account_with_cancel_partially_filled_orders()
{
  string account_id("a1");
  Account account(account_id);
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  string execution_id1("e1");
  string execution_id2("e2");
  string cancel_id1("c1");
  string cancel_id2("c2");
  account.add_order(isin_id, order_id1, Side::Buy, 2100, 12.50);
  account.add_order(isin_id, order_id2, Side::Sell, 1500, 12.0);
  account.execute(order_id1, execution_id1, 500, 12.50);
  account.execute(order_id2, execution_id2, 500, 12.00);
  account.cancel_order(order_id1);
  account.cancel_order(order_id2);
  Proceeds p1 = Proceeds(6000.0, 6250.0, 0.0, 0.0, isin_id);
  Proceeds p2 = account.proceeds_for_isin(isin_id);
  return p1 == p2;
}

bool test_accounts_with_cancel_partially_filled_orders()
{
  Accounts accounts;
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  string execution_id1("e1");
  string execution_id2("e2");
  string cancel_id1("c1");
  string cancel_id2("c2");
  accounts.add_order(account_id, isin_id, order_id1, Side::Buy, 2100, 12.50);
  accounts.add_order(account_id, isin_id, order_id2, Side::Sell, 1500, 12.0);
  accounts.execute(account_id, order_id1, execution_id1, 500, 12.50);
  accounts.execute(account_id, order_id2, execution_id2, 500, 12.00);
  accounts.cancel_order(account_id, order_id1);
  accounts.cancel_order(account_id, order_id2);
  Proceeds p1 = Proceeds(6000.0, 6250.0, 0.0, 0.0, isin_id);
  Proceeds p2 = accounts.proceeds_for_isin(account_id, isin_id);
  return p1 == p2;
}

bool test_clients_with_cancel_partially_filled_orders()
{
  Clients clients;
  string client_id("c1");
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  string execution_id1("e1");
  string execution_id2("e2");
  string cancel_id1("c1");
  string cancel_id2("c2");
  clients.add_order(client_id, account_id, isin_id, order_id1, Side::Buy, 2100, 12.50);
  clients.add_order(client_id, account_id, isin_id, order_id2, Side::Sell, 1500, 12.0);
  clients.execute(client_id, account_id, order_id1, execution_id1, 500, 12.50);
  clients.execute(client_id, account_id, order_id2, execution_id2, 500, 12.00);
  clients.cancel_order(client_id, account_id, order_id1);
  clients.cancel_order(client_id, account_id, order_id2);
  Proceeds p1 = Proceeds(6000.0, 6250.0, 0.0, 0.0, isin_id);
  Proceeds p2 = clients.proceeds_for_isin(client_id, account_id, isin_id);
  return p1 == p2;
}

bool test_clients_with_executions()
{
  Clients clients;
  string client_id("c1");
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  string execution_id1("e1");
  string execution_id2("e2");
  clients.add_order(client_id, account_id, isin_id, order_id1, Side::Buy, 2100, 12.50);
  clients.add_order(client_id, account_id, isin_id, order_id2, Side::Sell, 1500, 12.0);
  clients.execute(client_id, account_id, order_id1, execution_id1, 500, 12.50);
  clients.execute(client_id, account_id, order_id2, execution_id2, 500, 12.00);
  Proceeds p1 = Proceeds(6000.0, 6250.0, 12000.0, 20000.0, isin_id);
  Proceeds p2 = clients.proceeds_for_isin(client_id, account_id, isin_id);
  return p1 == p2;
}

bool test_clients_proceeds_with_cancel_partially_filled_orders()
{
  Clients clients;
  string client_id("c1");
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  string execution_id1("e1");
  string execution_id2("e2");
  string cancel_id1("c1");
  string cancel_id2("c2");
  clients.add_order(client_id, account_id, isin_id, order_id1, Side::Buy, 2100, 12.50);
  clients.add_order(client_id, account_id, isin_id, order_id2, Side::Sell, 1500, 12.0);
  clients.execute(client_id, account_id, order_id1, execution_id1, 500, 12.50);
  clients.execute(client_id, account_id, order_id2, execution_id2, 500, 12.00);
  clients.cancel_order(client_id, account_id, order_id1);
  Proceeds p1 = Proceeds(6000.0, 6250.0, 0.0, 0.0, isin_id);
  clients.proceeds_with_cancel(client_id, account_id, order_id2);
  Proceeds p2 = clients.proceeds_with_cancel(client_id, account_id, order_id2);
  return p1 == p2;
}

bool test_clients_proceeds_with_execution()
{
  Clients clients;
  string client_id("c1");
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  string execution_id1("e1");
  string execution_id2("e2");
  clients.add_order(client_id, account_id, isin_id, order_id1, Side::Buy, 2100, 12.50);
  clients.add_order(client_id, account_id, isin_id, order_id2, Side::Sell, 1500, 12.0);
  clients.execute(client_id, account_id, order_id1, execution_id1, 500, 12.50);
  Proceeds p1 = Proceeds(6000.0, 6250.0, 12000.0, 20000.0, isin_id);
  Proceeds p2 = clients.proceeds_with_execute(client_id, account_id, order_id2, execution_id2, 500, 12.00);
  return p1 == p2;
}

bool test_clients_with_agg_unit()
{
  Clients clients;
  string client_id("c1");
  string agg_unit_id("au1");
  string account_id1("a1");
  string account_id2("a2");
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  string execution_id1("e1");
  string execution_id2("e2");
  clients.add_order(client_id, account_id1, isin_id, order_id1, Side::Buy, 2100, 12.50);
  clients.add_order(client_id, account_id2, isin_id, order_id2, Side::Sell, 1500, 12.0);
  clients.execute(client_id, account_id1, order_id1, execution_id1, 500, 12.50);
  clients.execute(client_id, account_id2, order_id2, execution_id2, 500, 12.00);
  clients.create_agg_unit(client_id, agg_unit_id);
  clients.add_account_to_agg_unit(client_id, account_id1, agg_unit_id);
  clients.add_account_to_agg_unit(client_id, account_id2, agg_unit_id);
  Proceeds p1 = Proceeds(6000.0, 6250.0, 12000.0, 20000.0, "");
  Proceeds p2 = clients.proceeds_for_agg_unit(client_id, agg_unit_id);
  return p1 == p2;
}

bool test_clients_proceeds_for_client()
{
  Clients clients;
  string client_id("c1");
  string account_id1("a1");
  string account_id2("a2");
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  string execution_id1("e1");
  string execution_id2("e2");
  clients.add_order(client_id, account_id1, isin_id, order_id1, Side::Buy, 2100, 12.50);
  clients.add_order(client_id, account_id2, isin_id, order_id2, Side::Sell, 1500, 12.0);
  clients.execute(client_id, account_id1, order_id1, execution_id1, 500, 12.50);
  clients.execute(client_id, account_id2, order_id2, execution_id2, 500, 12.00);
  Proceeds p1 = Proceeds(6000.0, 6250.0, 12000.0, 20000.0, "");
  Proceeds p2 = clients.proceeds_for_client(client_id);
  return p1 == p2;
}

bool test_clients_proceeds_for_account()
{
  Clients clients;
  string client_id("c1");
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  string order_id2("o2");
  string execution_id1("e1");
  string execution_id2("e2");
  clients.add_order(client_id, account_id, isin_id, order_id1, Side::Buy, 2100, 12.50);
  clients.add_order(client_id, account_id, isin_id, order_id2, Side::Sell, 1500, 12.0);
  clients.execute(client_id, account_id, order_id1, execution_id1, 500, 12.50);
  clients.execute(client_id, account_id, order_id2, execution_id2, 500, 12.00);
  Proceeds p1 = Proceeds(6000.0, 6250.0, 12000.0, 20000.0, "");
  Proceeds p2 = clients.proceeds_for_account(client_id, account_id);
  return p1 == p2;
}

#define TEST(TEST_NAME) if (TEST_NAME()) { printf("passed: " #TEST_NAME "\n"); } else { printf("FAILED: " #TEST_NAME "\n"); }

int main(int argc, char** argv)
{
  TEST(test_proceeds);
  TEST(test_proceeds_add);
  TEST(test_order);
  TEST(test_orders);
  TEST(test_isin);
  TEST(test_isins);
  TEST(test_isins_first_proceeds);
  TEST(test_account);
  TEST(test_accounts);
  TEST(test_accounts_first_proceeds)
  TEST(test_client);
  TEST(test_clients);
  TEST(test_clients_first_proceeds);
  TEST(test_clients_proceeds_with_cancel);
  TEST(test_clients_cancel);
  TEST(test_orders_with_executions);
  TEST(test_isin_with_filled_order);
  TEST(test_isin_with_cancel_partially_filled_orders);
  TEST(test_isins_with_cancel_partially_filled_orders);
  TEST(test_account_with_cancel_partially_filled_orders);
  TEST(test_accounts_with_cancel_partially_filled_orders);
  TEST(test_clients_with_cancel_partially_filled_orders);
  TEST(test_clients_with_executions);
  TEST(test_clients_proceeds_with_cancel_partially_filled_orders);
  TEST(test_clients_proceeds_with_execution);
  TEST(test_clients_with_agg_unit);
  TEST(test_clients_proceeds_for_client);
  TEST(test_clients_proceeds_for_account);
  return 0;
}
