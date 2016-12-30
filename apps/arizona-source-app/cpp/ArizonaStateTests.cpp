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
  Proceeds p1 = Proceeds(0.0, 1900.0, 0, 0.0, "");
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
  Proceeds p1 = Proceeds(0.0, 1900.0, 0, 0.0, isin_id);
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
  Proceeds p1 = Proceeds(0.0, 1900.0, 0, 0.0, isin_id);
  Proceeds p2 = isins.proceeds_with_order(isin_id, order_id2, Side::Buy, 20, 70.0);
  return p1 == p2;
}

bool test_isins_first_proceeds()
{
  ISINs isins;
  string isin_id("i1");
  ISIN isin(isin_id);
  string order_id1("o1");
  Proceeds p1 = Proceeds(0.0, 1400.0, 0, 0.0, isin_id);
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
  Proceeds p1 = Proceeds(0.0, 1900.0, 0, 0.0, isin_id);
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
  Proceeds p1 = Proceeds(0.0, 1900.0, 0, 0.0, isin_id);
  Proceeds p2 = accounts.proceeds_with_order(account_id, isin_id, order_id2, Side::Buy, 20, 70.0);
  return p1 == p2;
}

bool test_accounts_first_proceeds()
{
  Accounts accounts;
  string account_id("a1");
  string isin_id("i1");
  string order_id1("o1");
  Proceeds p1 = Proceeds(0.0, 1400.0, 0, 0.0, isin_id);
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
  Proceeds p1 = Proceeds(0.0, 1900.0, 0, 0.0, isin_id);
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
  Proceeds p1 = Proceeds(0.0, 1900.0, 0, 0.0, isin_id);
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
  Proceeds p1 = Proceeds(0.0, 1400.0, 0, 0.0, isin_id);
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
  Proceeds p1 = Proceeds(0.0, 3500.0, 0.0, 0.0, isin_id);
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
  Proceeds p1 = Proceeds(0.0, 3500.0, 0.0, 0.0, isin_id);
  clients.add_order(client_id, account_id, isin_id, order_id1, Side::Buy, 20, 70.0);
  clients.add_order(client_id, account_id, isin_id, order_id2, Side::Buy, 10, 70.0);
  clients.add_order(client_id, account_id, isin_id, order_id3, Side::Buy, 40, 70.0);
  Proceeds p2 = clients.proceeds_with_cancel(client_id, account_id, order_id1);
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
  return 0;
}
