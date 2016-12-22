#include "ArizonaState.hpp"

Proceeds::Proceeds(double proceeds_short_, double proceeds_long_, double open_short_, double open_long_):
  _proceeds_short(proceeds_short_), _proceeds_long(proceeds_long_), _open_short(open_short_), _open_long(open_long_)
{
}

Proceeds& Proceeds::add(Proceeds& that)
{
  _proceeds_short += that._proceeds_short;
  _proceeds_long += that._proceeds_long;
  _open_short += that._open_short;
  _open_long += that._open_long;

  return *this;
}

bool Proceeds::operator==(Proceeds& that)
{
  return (_proceeds_short == that._proceeds_short)
    && (_proceeds_long == that._proceeds_long)
    && (_open_short == that._open_short)
    && (_open_long == that._open_long);
}

Order::Order(string& order_id_, Side side_, uint32_t quantity_, double price_):
  _order_id(order_id_), _side(side_), _quantity(quantity_), _price(price_)
{
}

bool Order::operator==(Order& that)
{
  return (_order_id == that._order_id) && (_side == that._side) && (_quantity == that._quantity) && (_price == that._price);
}

Proceeds Order::proceeds()
{
  double total = _quantity * _price;
  switch (_side)
  {
  default:
    // TODO: Log this
    return Proceeds(0.0, 0.0, 0.0, 0.0);
  case Side::Sell:
    return Proceeds(total, 0.0, 0.0, 0.0);
  case Side::Buy:
    return Proceeds(0.0, total, 0.0, 0.0);
  }
}

Orders::Orders(): _orders()
{
}

Orders::~Orders()
{
  for(map<string, Order *>::iterator it = _orders.begin(); it != _orders.end(); it++)
  {
    delete it->second;
  }
}

void Orders::add_order(string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  _orders.insert(std::pair<string, Order*>(order_id_, new Order(order_id_, side_, quantity_, price_)));
}

Proceeds Orders::proceeds()
{
  Proceeds p(0.0, 0.0, 0.0, 0.0);
  for(map<string, Order *>::iterator it = _orders.begin(); it != _orders.end(); it++)
  {
    Proceeds p_order = it->second->proceeds();
    p.add(p_order);
  }

  return p;
}

ISIN::ISIN(string& isin_id_): _isin_id(isin_id_)
{
}

void ISIN::add_order(string& order_id_, Side side_, double quantity_, double price_)
{
  _orders.add_order(order_id_, side_, quantity_, price_);
}

Proceeds ISIN::proceeds()
{
  return _orders.proceeds();
}

ISINs::ISINs(): _isins()
{
}

ISINs::~ISINs()
{
  for(map<string, ISIN *>::iterator it = _isins.begin(); it != _isins.end(); it++)
  {
    delete it->second;
  }
}

ISIN* ISINs::_isin_by_isin_id(string& isin_id_)
{
  map<string, ISIN*>::iterator it = _isins.find(isin_id_);

  if (it == _isins.end())
  {
    return nullptr;
  }

  return it->second;
}

ISIN* ISINs::_add_isin(string& isin_id_)
{
  ISIN *isin = new ISIN(isin_id_);
  _isins.insert(std::pair<string, ISIN*>(isin_id_, isin));
  return isin;
}

void ISINs::add_order(string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  // look up isin by isin_id_

  ISIN *isin = _isin_by_isin_id(isin_id_);

  if (isin == nullptr)
  {
    isin = _add_isin(isin_id_);
  }

  isin->add_order(order_id_, side_, quantity_, price_);
}

Proceeds ISINs::proceeds_for_isin(string& isin_id_)
{
  // look up isin by isin_id_

  ISIN *isin = _isin_by_isin_id(isin_id_);

  // TODO: log if we can't find the isin
  if (isin == nullptr)
  {
    return Proceeds(0.0, 0.0, 0.0, 0.0);
  }

  return isin->proceeds();
}

Proceeds ISINs::proceeds_with_order(string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  Proceeds p_isin = proceeds_for_isin(isin_id_);
  Proceeds p_order = Order(order_id_, side_, quantity_, price_).proceeds();
  return p_order.add(p_isin);
}

Account::Account(string& account_id_): _account_id(account_id_), _isins()
{
}

void Account::add_order(string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  _isins.add_order(isin_id_, order_id_, side_, quantity_, price_);
}

Proceeds Account::proceeds_for_isin(string& isin_id_)
{
  return _isins.proceeds_for_isin(isin_id_);
}

Proceeds Account::proceeds_with_order(string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  return _isins.proceeds_with_order(isin_id_, order_id_, side_, quantity_, price_);
}

Accounts::Accounts(): _accounts()
{
}

Accounts::~Accounts()
{
  for(map<string, Account *>::iterator it = _accounts.begin(); it != _accounts.end(); it++)
  {
    delete it->second;
  }
}

Account *Accounts::_account_by_account_id(string& account_id_)
{
  map<string, Account*>::iterator it = _accounts.find(account_id_);

  if (it == _accounts.end())
  {
    return nullptr;
  }

  return it->second;
}

Account* Accounts::_add_account(string& account_id_)
{
  Account *account = new Account(account_id_);
  _accounts.insert(std::pair<string, Account*>(account_id_, account));

  return account;
}

void Accounts::add_order(string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  Account *account = _account_by_account_id(account_id_);

  if (account == nullptr)
  {
    account = _add_account(account_id_);
  }

  account->add_order(isin_id_, order_id_, side_, quantity_, price_);
}

Proceeds Accounts::proceeds_for_isin(string& account_id_, string& isin_id_)
{
  Account *account = _account_by_account_id(account_id_);
  if (account == nullptr)
  {
    return Proceeds(0.0, 0.0, 0.0, 0.0);
  }
  return account->proceeds_for_isin(isin_id_);
}

Proceeds Accounts::proceeds_with_order(string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  Account *account = _account_by_account_id(account_id_);

  if (account == nullptr)
  {
    return Order(order_id_, side_, quantity_, price_).proceeds();
  }
  return account->proceeds_with_order(isin_id_, order_id_, side_, quantity_, price_);
}

Client::Client(string& client_id_): _client_id(client_id_)
{
}

void Client::add_order(string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  _accounts.add_order(account_id_, isin_id_, order_id_, side_, quantity_, price_);
}

Proceeds Client::proceeds_for_isin(string& account_id_, string& isin_id_)
{
  return _accounts.proceeds_for_isin(account_id_, isin_id_);
}

Proceeds Client::proceeds_with_order(string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  return _accounts.proceeds_with_order(account_id_, isin_id_, order_id_, side_, quantity_, price_);
}

Clients::Clients(): _clients()
{
}

Client *Clients::_client_by_client_id(string& client_id_)
{
  map<string, Client*>::iterator it = _clients.find(client_id_);

  if (it == _clients.end())
  {
    return nullptr;
  }

  return it->second;
}

Clients::~Clients()
{
  for(map<string, Client *>::iterator it = _clients.begin(); it != _clients.end(); it++)
  {
    delete it->second;
  }
}

Client* Clients::_add_client(string& client_id_)
{
  Client *client = new Client(client_id_);
  _clients.insert(std::pair<string, Client*>(client_id_, client));

  return client;
}

void Clients::add_order(string& client_id_, string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    client = _add_client(client_id_);
  }

  client->add_order(account_id_, isin_id_, order_id_, side_, quantity_, price_);
}

Proceeds Clients::proceeds_for_isin(string& client_id_, string& account_id_, string& isin_id_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    return Proceeds(0.0, 0.0, 0.0, 0.0);
  }
  return client->proceeds_for_isin(account_id_, isin_id_);
}

Proceeds Clients::proceeds_with_order(string& client_id_, string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    return Order(order_id_, side_, quantity_, price_).proceeds();
  }
  return client->proceeds_with_order(account_id_, isin_id_, order_id_, side_, quantity_, price_);
}
