#include "ArizonaState.hpp"

Proceeds::Proceeds(double proceeds_short_, double proceeds_long_, double open_short_, double open_long_, string isin_id_):
  _proceeds_short(proceeds_short_), _proceeds_long(proceeds_long_), _open_short(open_short_), _open_long(open_long_), _isin_id(isin_id_)
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
    && (_open_long == that._open_long)
    && (_isin_id == that._isin_id);
}

Execution::Execution(string& execution_id_, Side side_, uint32_t quantity_, double price_):
  _side(side_), _quantity(quantity_), _price(price_), _proceeds(0.0, 0.0, 0.0, 0.0, "")
{
  double total = quantity_ * price_;
  if (side_ == Side::Buy)
  {
    _proceeds = Proceeds(0.0, total, 0.0, -total, "");
  }
  else
  {
    _proceeds = Proceeds(total, 0.0, -total, 0.0, "");
  }
}

ExecutionResult Executions::execute(string& execution_id_, Side side_, uint32_t quantity_, double price_, uint32_t order_quantity_)
{
  uint32_t total_quantity = quantity_;
  for (vector<Execution>::iterator it = _executions.begin(); it != _executions.end(); it++)
  {
    total_quantity += it->quantity();
  }

  if (total_quantity > order_quantity_)
  {
    return ExecutionNotAdded;
  }

  Execution e(execution_id_, side_, quantity_, price_);
  _executions.push_back(e);

  if (total_quantity == order_quantity_)
  {
    return ExecutionFilledOrder;
  }

  return ExecutionAdded;
}

Proceeds Executions::proceeds()
{
  Proceeds p = Proceeds(0.0, 0.0, 0.0, 0.0, "");

  for(vector<Execution>::iterator it = _executions.begin(); it != _executions.end(); it++)
  {
    Proceeds pe = it->proceeds();
    p.add(pe);
  }

  return p;
}

Proceeds Executions::proceeds_with_execute(string& execution_id_, Side side_, uint32_t quantity_, double price_)
{
  Proceeds p = Proceeds(0.0, 0.0, 0.0, 0.0, "");

  for(vector<Execution>::iterator it = _executions.begin(); it != _executions.end(); it++)
  {
    Proceeds pe = it->proceeds();
    p.add(pe);
  }

  Execution e(execution_id_, side_, quantity_, price_);

  Proceeds pe = e.proceeds();

  p.add(pe);

  return p;
}

uint32_t Executions::quantity()
{
  uint32_t sum_quantity = 0;

  for(vector<Execution>::iterator it = _executions.begin(); it != _executions.end(); it++)
  {
    sum_quantity = it->quantity();
  }

  return sum_quantity;
}

Order::Order(string& order_id_, Side side_, uint32_t quantity_, double price_):
  _executions(), _order_id(order_id_), _side(side_), _quantity(quantity_), _price(price_)
{
}

bool Order::operator==(Order& that)
{
  return (_order_id == that._order_id) && (_side == that._side) && (_quantity == that._quantity) && (_price == that._price);
}

Proceeds Order::base_proceeds()
{
  double total = _quantity * _price;
  switch (_side)
  {
  default:
    // TODO: Log this
    return Proceeds(-1.0, -1.0, -1.0, -1.0, "");
  case Side::Sell:
    return Proceeds(0.0, 0.0, total, 0.0, "");
  case Side::Buy:
    return Proceeds(0.0, 0.0, 0.0, total, "");
  }
}

Proceeds Order::proceeds()
{
  Proceeds p = _executions.proceeds();

  Proceeds bp = base_proceeds();

  p.add(bp);

  return p;
}

Proceeds Order::proceeds_with_execute(string& execution_id_, uint32_t quantity_, double price_)
{
  Proceeds bp = base_proceeds();

  if (quantity_ > (_quantity - _executions.quantity()))
  {
    // TODO: we should signal an error if the quantity executed exceeds the quantity available
    Proceeds p = _executions.proceeds();
    bp.add(p);
    return bp;
  }

  Proceeds p = _executions.proceeds_with_execute(execution_id_, _side, quantity_, price_);
  bp.add(p);
  return bp;
}

ExecutionResult Order::execute(string& execution_id_, uint32_t quantity_, double price_, ISIN *isin_)
{
  ExecutionResult execution_result = _executions.execute(execution_id_, _side, quantity_, price_, _quantity);

  if (execution_result == ExecutionFilledOrder)
  {
    Proceeds op = final_proceeds();
    isin_->add_proceeds(op);
  }

  return execution_result;
}

Proceeds Order::final_proceeds()
{
  Proceeds pe = _executions.proceeds();

  Proceeds p(pe.proceeds_short(), pe.proceeds_long(), 0.0, 0.0, "");

  return p;
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
  map<string, Order *>::iterator it = _orders.find(order_id_);
  if (it != _orders.end())
  {
    // TODO: this should be an error
    return;
  }

  Order *order = new Order(order_id_, side_, quantity_, price_);
  _orders.insert(std::pair<string, Order*>(order_id_, order));
}

void Orders::cancel_order(string& order_id_, ISIN *isin_)
{
  map<string, Order *>::iterator it = _orders.find(order_id_);
  if (it == _orders.end())
  {
    // TODO: this should probably be an error
    return;
  }

  Proceeds final_proceeds = it->second->final_proceeds();
  isin_->add_proceeds(final_proceeds);

  delete it->second;
  _orders.erase(it);
}

bool Orders::execute(string& order_id_, string& execution_id_, uint32_t quantity_, double price_, ISIN *isin_)
{
  map<string, Order *>::iterator it = _orders.find(order_id_);
  if (it == _orders.end())
  {
    // TODO: this should probably be an error
    return false;
  }

  if (it->second->execute(execution_id_, quantity_, price_, isin_) == ExecutionFilledOrder)
  {
    delete it->second;
    _orders.erase(it);

    return true;
  }

  return false;
}

Proceeds Orders::proceeds()
{
  Proceeds p(0.0, 0.0, 0.0, 0.0, "");
  for(map<string, Order *>::iterator it = _orders.begin(); it != _orders.end(); it++)
  {
    Proceeds p_order = it->second->proceeds();
    p.add(p_order);
  }

  return p;
}

Proceeds Orders::proceeds_with_cancel(string& order_id_)
{
  Proceeds p(0.0, 0.0, 0.0, 0.0, "");
  for(map<string, Order *>::iterator it = _orders.begin(); it != _orders.end(); it++)
  {
    if (it->first != order_id_)
    {
      Proceeds p_order = it->second->proceeds();
      p.add(p_order);
    }
    else
    {
      Proceeds p_final = it->second->final_proceeds();
      p.add(p_final);
    }
  }

  return p;
}

Proceeds Orders::proceeds_with_execute(string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  // TODO: maybe there should be a way of signalling an error if the order id isn't found
  Proceeds p(0.0, 0.0, 0.0, 0.0, "");
  for(map<string, Order *>::iterator it = _orders.begin(); it != _orders.end(); it++)
  {
    if (it->first != order_id_)
    {
      Proceeds p_order = it->second->proceeds();
      p.add(p_order);
    }
    else
    {
      Proceeds p_with_execute = it->second->proceeds_with_execute(execution_id_, quantity_, price_);
      p.add(p_with_execute);
    }
  }

  return p;
}

ISIN::ISIN(string& isin_id_): _isin_id(isin_id_), _proceeds(0.0, 0.0, 0.0, 0.0, isin_id_)
{
}

void ISIN::add_order(string& order_id_, Side side_, double quantity_, double price_, Account *account_)
{
  account_->associate_order_id_to_isin_id(order_id_, _isin_id);
  _orders.add_order(order_id_, side_, quantity_, price_);
}

void ISIN::cancel_order(string& order_id_)
{
  _orders.cancel_order(order_id_, this);
}

bool ISIN::execute(string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  return _orders.execute(order_id_, execution_id_, quantity_, price_, this);
}

Proceeds ISIN::proceeds()
{
  Proceeds p = _proceeds;
  Proceeds op = _orders.proceeds();
  return p.add(op);
}

Proceeds ISIN::proceeds_with_cancel(string& order_id_)
{
  Proceeds p = _proceeds;
  Proceeds op = _orders.proceeds_with_cancel(order_id_);
  return p.add(op);
}

Proceeds ISIN::proceeds_with_execute(string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  Proceeds p = _proceeds;
  Proceeds op = _orders.proceeds_with_execute(order_id_, execution_id_, quantity_, price_);
  return p.add(op);
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

void ISINs::add_order(string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_, Account *account_)
{
  // look up isin by isin_id_

  ISIN *isin = _isin_by_isin_id(isin_id_);

  if (isin == nullptr)
  {
    isin = _add_isin(isin_id_);
  }

  isin->add_order(order_id_, side_, quantity_, price_, account_);
}

void ISINs::cancel_order(string& isin_id_, string& order_id_)
{
  // look up isin by isin_id_

  ISIN *isin = _isin_by_isin_id(isin_id_);

  if (isin == nullptr)
  {
    // TODO: This should probably be an error
    return;
  }

  isin->cancel_order(order_id_);
}

bool ISINs::execute(string& isin_id_, string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  // look up isin by isin_id_

  ISIN *isin = _isin_by_isin_id(isin_id_);

  if (isin == nullptr)
  {
    // TODO: This should probably be an error
    return false;
  }

  return isin->execute(order_id_, execution_id_, quantity_, price_);
}

Proceeds ISINs::proceeds_for_isin(string& isin_id_)
{
  // look up isin by isin_id_

  ISIN *isin = _isin_by_isin_id(isin_id_);

  // TODO: log if we can't find the isin
  if (isin == nullptr)
  {
    return Proceeds(0.0, 0.0, 0.0, 0.0, isin_id_);
  }

  return isin->proceeds();
}

Proceeds ISINs::proceeds_with_order(string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  Proceeds p_isin = proceeds_for_isin(isin_id_);
  Proceeds p_order = Order(order_id_, side_, quantity_, price_).proceeds();
  return p_isin.add(p_order);
}

Proceeds ISINs::proceeds_with_cancel(string& isin_id_, string& order_id_)
{
  // look up isin by isin_id_

  ISIN *isin = _isin_by_isin_id(isin_id_);

  // TODO: log if we can't find the isin
  if (isin == nullptr)
  {
    return Proceeds(0.0, 0.0, 0.0, 0.0, isin_id_);
  }

  return isin->proceeds_with_cancel(order_id_);
}

Proceeds ISINs::proceeds_with_execute(string& isin_id_, string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  // look up isin by isin_id_

  ISIN *isin = _isin_by_isin_id(isin_id_);

  // TODO: log if we can't find the isin
  if (isin == nullptr)
  {
    return Proceeds(0.0, 0.0, 0.0, 0.0, isin_id_);
  }

  return isin->proceeds_with_execute(order_id_, execution_id_, quantity_, price_);
}

Proceeds ISINs::all_proceeds()
{
  Proceeds p(0.0, 0.0, 0.0, 0.0, "");

  for(map<string, ISIN*>::iterator it = _isins.begin(); it != _isins.end(); it++)
  {
    Proceeds pi = it->second->proceeds();
    p.add(pi);
  }

  return p;
}

Account::Account(string& account_id_): _account_id(account_id_), _isins(), _order_id_to_isin_id()
{
}

void Account::add_order(string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  _isins.add_order(isin_id_, order_id_, side_, quantity_, price_, this);
}

void Account::cancel_order(string& isin_id_, string& order_id_)
{
  _isins.cancel_order(isin_id_, order_id_);
}

void Account::cancel_order(string& order_id_)
{
  map<string, string>::iterator it = _order_id_to_isin_id.find(order_id_);
  if (it == _order_id_to_isin_id.end())
  {
    // TODO: this should be an error
    return;
  }
  string isin_id = it->second;
  _isins.cancel_order(isin_id, order_id_);
  // disassociate can safely be done here because if we got this far then the order_id is in the map
  disassociate_order_id_to_isin_id(order_id_, isin_id);
}

void Account::execute(string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  map<string, string>::iterator it = _order_id_to_isin_id.find(order_id_);
  if (it == _order_id_to_isin_id.end())
  {
    // TODO: this should be an error
    return;
  }
  string isin_id = it->second;
  bool filled = _isins.execute(isin_id, order_id_, execution_id_, quantity_, price_);
  if (filled)
  {
    disassociate_order_id_to_isin_id(order_id_, isin_id);
  }
}

Proceeds Account::proceeds_for_isin(string& isin_id_)
{
  return _isins.proceeds_for_isin(isin_id_);
}

Proceeds Account::proceeds_with_order(string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  return _isins.proceeds_with_order(isin_id_, order_id_, side_, quantity_, price_);
}

Proceeds Account::proceeds_with_cancel(string& isin_id_, string& order_id_)
{
  return _isins.proceeds_with_cancel(isin_id_, order_id_);
}

Proceeds Account::proceeds_with_cancel(string& order_id_)
{
  map<string, string>::iterator it = _order_id_to_isin_id.find(order_id_);
  if (it == _order_id_to_isin_id.end())
  {
    // TODO: this should be an error
    return Proceeds(-1.0 ,-1.0, -1.0, -1.0, "");
  }
  string isin_id = it->second;

  return _isins.proceeds_with_cancel(isin_id, order_id_);
}

Proceeds Account::proceeds_with_execute(string& isin_id_, string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  return _isins.proceeds_with_execute(isin_id_, order_id_, execution_id_, quantity_, price_);
}

Proceeds Account::proceeds_with_execute(string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  map<string, string>::iterator it = _order_id_to_isin_id.find(order_id_);
  if (it == _order_id_to_isin_id.end())
  {
    // TODO: this should be an error
    return Proceeds(-1.0 ,-1.0, -1.0, -1.0, "");
  }
  string isin_id = it->second;

  return _isins.proceeds_with_execute(isin_id, order_id_, execution_id_, quantity_, price_);
}

Proceeds Account::all_proceeds()
{
  return _isins.all_proceeds();
}

void Account::associate_order_id_to_isin_id(string& order_id_, string& isin_id_)
{
  _order_id_to_isin_id.insert(std::pair<string, string>(order_id_, isin_id_));
}

void Account::disassociate_order_id_to_isin_id(string& order_id_, string& isin_id_)
{
  map<string, string>::iterator it = _order_id_to_isin_id.find(order_id_);
  if (it == _order_id_to_isin_id.end())
  {
    // TODO: this should probably be an error
    return;
  }

  _order_id_to_isin_id.erase(it);
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

Account* Accounts::_add_account(string& account_id_)
{
  Account *account = new Account(account_id_);
  _accounts.insert(std::pair<string, Account*>(account_id_, account));

  return account;
}

Account *Accounts::account_by_account_id(string& account_id_)
{
  map<string, Account*>::iterator it = _accounts.find(account_id_);

  if (it == _accounts.end())
  {
    return nullptr;
  }

  return it->second;
}

void Accounts::add_order(string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  Account *account = account_by_account_id(account_id_);

  if (account == nullptr)
  {
    account = _add_account(account_id_);
  }

  account->add_order(isin_id_, order_id_, side_, quantity_, price_);
}

void Accounts::cancel_order(string& account_id_, string& order_id_)
{
  Account *account = account_by_account_id(account_id_);

  if (account == nullptr)
  {
    // TODO: this should probably be an error
    return;
  }

  account->cancel_order(order_id_);
}

void Accounts::execute(string& account_id_, string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  Account *account = account_by_account_id(account_id_);

  if (account == nullptr)
  {
    // TODO: this should probably be an error
    return;
  }

  account->execute(order_id_, execution_id_, quantity_, price_);
}

Proceeds Accounts::proceeds_for_isin(string& account_id_, string& isin_id_)
{
  Account *account = account_by_account_id(account_id_);
  if (account == nullptr)
  {
    return Proceeds(0.0, 0.0, 0.0, 0.0, isin_id_);
  }
  return account->proceeds_for_isin(isin_id_);
}

Proceeds Accounts::proceeds_with_order(string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  Account *account = account_by_account_id(account_id_);

  if (account == nullptr)
  {
    Proceeds p(0.0, 0.0, 0.0, 0.0, isin_id_);
    Proceeds op = Order(order_id_, side_, quantity_, price_).proceeds();
    return p.add(op);
  }
  return account->proceeds_with_order(isin_id_, order_id_, side_, quantity_, price_);
}

Proceeds Accounts::proceeds_with_cancel(string& account_id_, string& order_id_)
{
  Account *account = account_by_account_id(account_id_);

  if (account == nullptr)
  {
    // TODO: canceling an order for an account that doesn't exist should be an error
    return Proceeds(-1.0, -1.0, -1.0, -1.0, "");
  }
  return account->proceeds_with_cancel(order_id_);
}

Proceeds Accounts::proceeds_with_execute(string& account_id_, string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  Account *account = account_by_account_id(account_id_);

  if (account == nullptr)
  {
    // TODO: executing  an order for an account that doesn't exist should be an error
    return Proceeds(-1.0, -1.0, -1.0, -1.0, "");
  }
  return account->proceeds_with_execute(order_id_, execution_id_, quantity_, price_);
}

Proceeds Accounts::proceeds()
{
  Proceeds p(0.0, 0.0, 0.0, 0.0, "");
  for(map<string, Account *>::iterator it = _accounts.begin(); it != _accounts.end(); it++)
  {
    Proceeds pa = it->second->all_proceeds();
    p.add(pa);
  }
  return p;
}

Proceeds Accounts::proceeds_for_account(string& account_id_)
{
  Account *account = account_by_account_id(account_id_);

  if (account == nullptr)
  {
    // TODO: executing  an order for an account that doesn't exist should be an error
    return Proceeds(-1.0, -1.0, -1.0, -1.0, "");
  }
  return account->all_proceeds();
}

AggUnit::AggUnit(string& agg_unit_id_): _agg_unit_id(agg_unit_id_), _accounts()
{
}

Proceeds AggUnit::proceeds()
{
  Proceeds p(0.0, 0.0, 0.0, 0.0, "");
  for (vector<Account *>::iterator it = _accounts.begin(); it != _accounts.end(); it++)
  {
    Proceeds pa = (*it)->all_proceeds();
    p.add(pa);
  }

  return p;
}

void AggUnit::add_account(Account *account_)
{
  _accounts.push_back(account_);
}

void AggUnit::remove_account(Account *account_)
{
  for (vector<Account *>::iterator it = _accounts.begin();
       it != _accounts.end();
       it++)
  {
    if (*it == account_)
    {
      _accounts.erase(it);
      break;
    }
  }
}

AggUnits::AggUnits(): _agg_unit_id_to_agg_unit()
{
}

void AggUnits::create_agg_unit(string& agg_unit_id_)
{
  map<string, AggUnit>::iterator it = _agg_unit_id_to_agg_unit.find(agg_unit_id_);

  if (it != _agg_unit_id_to_agg_unit.end())
  {
    // TODO: should this be an error?
    return;
  }

  AggUnit au(agg_unit_id_);

  _agg_unit_id_to_agg_unit.insert(std::pair<string, AggUnit>(agg_unit_id_, au));
}

Proceeds AggUnits::proceeds_for_agg_unit(string& agg_unit_id)
{
  Proceeds p = Proceeds(0.0, 0.0, 0.0, 0.0, "");

  for(map<string, AggUnit>::iterator it = _agg_unit_id_to_agg_unit.begin();
      it != _agg_unit_id_to_agg_unit.end();
      it++)
  {
    Proceeds pa = it->second.proceeds();
    p.add(pa);
  }

  return p;
}

void AggUnits::add_account(string& agg_unit_id_, Account *account_)
{
  map<string, AggUnit>::iterator it = _agg_unit_id_to_agg_unit.find(agg_unit_id_);

  if (it == _agg_unit_id_to_agg_unit.end())
  {
    // TODO: should this be an error?
    return;
  }

  it->second.add_account(account_);
}

void AggUnits::remove_account(string& agg_unit_id_, Account *account_)
{
  map<string, AggUnit>::iterator it = _agg_unit_id_to_agg_unit.find(agg_unit_id_);

  if (it == _agg_unit_id_to_agg_unit.end())
  {
    // TODO: should this be an error?
    return;
  }

  it->second.remove_account(account_);
}

Client::Client(string& client_id_): _accounts(), _agg_units(), _client_id(client_id_)
{
}

void Client::add_order(string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  _accounts.add_order(account_id_, isin_id_, order_id_, side_, quantity_, price_);
}

void Client::cancel_order(string& account_id_, string& order_id_)
{
  _accounts.cancel_order(account_id_, order_id_);
}

void Client::execute(string& account_id_, string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  _accounts.execute(account_id_, order_id_, execution_id_, quantity_, price_);
}

Proceeds Client::proceeds_for_isin(string& account_id_, string& isin_id_)
{
  return _accounts.proceeds_for_isin(account_id_, isin_id_);
}

Proceeds Client::proceeds_with_order(string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  return _accounts.proceeds_with_order(account_id_, isin_id_, order_id_, side_, quantity_, price_);
}

Proceeds Client::proceeds_with_cancel(string& account_id_, string& order_id_)
{
  return _accounts.proceeds_with_cancel(account_id_, order_id_);
}

Proceeds Client::proceeds_with_execute(string& account_id_, string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  return _accounts.proceeds_with_execute(account_id_, order_id_, execution_id_, quantity_, price_);
}

Proceeds Client::proceeds()
{
  return _accounts.proceeds();
}

Proceeds Client::proceeds_for_account(string& account_id_)
{
  return _accounts.proceeds_for_account(account_id_);
}

Proceeds Client::proceeds_for_agg_unit(string& agg_unit_id_)
{
  return _agg_units.proceeds_for_agg_unit(agg_unit_id_);
}

void Client::create_agg_unit(string& agg_unit_id_)
{
  _agg_units.create_agg_unit(agg_unit_id_);
}

void Client::add_account_to_agg_unit(string& account_id_, string& agg_unit_id_)
{
  Account *account = _accounts.account_by_account_id(account_id_);

  if (account == nullptr)
  {
    // TODO: this should be an error.
    return;
  }

  _agg_units.add_account(agg_unit_id_, account);
}

void Client::remove_account_from_agg_unit(string& account_id_, string& agg_unit_id_)
{
  Account *account = _accounts.account_by_account_id(account_id_);

  if (account == nullptr)
  {
    // TODO: this should be an error.
    return;
  }

  _agg_units.remove_account(agg_unit_id_, account);
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

void Clients::cancel_order(string& client_id_, string& account_id_, string& order_id_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    // TODO: this should probably be an error
    return;
  }

  client->cancel_order(account_id_, order_id_);
}

void Clients::execute(string& client_id_, string& account_id_, string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    // TODO: this should probably be an error
    return;
  }

  client->execute(account_id_, order_id_, execution_id_, quantity_, price_);
}

Proceeds Clients::proceeds_for_isin(string& client_id_, string& account_id_, string& isin_id_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    return Proceeds(0.0, 0.0, 0.0, 0.0, isin_id_);
  }
  return client->proceeds_for_isin(account_id_, isin_id_);
}

Proceeds Clients::proceeds_with_order(string& client_id_, string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    Proceeds p = Proceeds(0.0, 0.0, 0.0, 0.0, isin_id_);
    Proceeds op = Order(order_id_, side_, quantity_, price_).proceeds();
    return p.add(op);
  }
  return client->proceeds_with_order(account_id_, isin_id_, order_id_, side_, quantity_, price_);
}

Proceeds Clients::proceeds_with_cancel(string& client_id_, string& account_id_, string& order_id_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    // TODO: it should be an error to cancel an order for a client that doesn't exist
    return Proceeds(0.0, 0.0, 0.0, 0.0, "");
  }
  return client->proceeds_with_cancel(account_id_, order_id_);
}

Proceeds Clients::proceeds_with_execute(string& client_id_, string& account_id_, string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    // TODO: it should be an error to cancel an order for a client that doesn't exist
    return Proceeds(0.0, 0.0, 0.0, 0.0, "");
  }
  return client->proceeds_with_execute(account_id_, order_id_, execution_id_, quantity_, price_);
}

Proceeds Clients::proceeds_for_client(string& client_id_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    // TODO: it should be an error to do something for a client that doesn't exist
    return Proceeds(0.0, 0.0, 0.0, 0.0, "");
  }
  return client->proceeds();
}

Proceeds Clients::proceeds_for_account(string& client_id_, string& account_id_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    // TODO: it should be an error to do something for a client that doesn't exist
    return Proceeds(0.0, 0.0, 0.0, 0.0, "");
  }
  return client->proceeds_for_account(account_id_);
}

Proceeds Clients::proceeds_for_agg_unit(string& client_id_, string& agg_unit_id_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    // TODO: it should be an error to do something for a client that doesn't exist
    return Proceeds(0.0, 0.0, 0.0, 0.0, "");
  }
  return client->proceeds_for_agg_unit(agg_unit_id_);
}

void Clients::create_agg_unit(string& client_id_, string& agg_unit_id_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    // TODO: it should be an error to do something for a client that doesn't exist
    return;
  }
  return client->create_agg_unit(agg_unit_id_);
}

void Clients::add_account_to_agg_unit(string& client_id_, string& account_id_, string& agg_unit_id_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    // TODO: it should be an error to do something for a client that doesn't exist
    return;
  }
  client->add_account_to_agg_unit(account_id_, agg_unit_id_);
}

void Clients::remove_account_from_agg_unit(string& client_id_, string& account_id_, string& agg_unit_id_)
{
  Client *client = _client_by_client_id(client_id_);

  if (client == nullptr)
  {
    // TODO: it should be an error to do something for a client that doesn't exist
    return;
  }
  client->remove_account_from_agg_unit(account_id_, agg_unit_id_);
}
