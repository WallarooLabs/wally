#include "market-spread-cpp.hpp"
#include "WallarooCppApi/ApiHooks.hpp"

#include <iostream>
#include <cstring>

// OS X doesn't include the endian conversion functions we need, so
// I've resorted to this.  https://gist.github.com/panzi/6856583
#if defined(__linux__)
#include <endian.h>
#elif defined(__APPLE__)
#include <libkern/OSByteOrder.h>
#define htobe16(x) OSSwapHostToBigInt16(x)
#define htole16(x) OSSwapHostToLittleInt16(x)
#define be16toh(x) OSSwapBigToHostInt16(x)
#define le16toh(x) OSSwapLittleToHostInt16(x)
#define htobe32(x) OSSwapHostToBigInt32(x)
#define htole32(x) OSSwapHostToLittleInt32(x)
#define be32toh(x) OSSwapBigToHostInt32(x)
#define le32toh(x) OSSwapLittleToHostInt32(x)
#define htobe64(x) OSSwapHostToBigInt64(x)
#define htole64(x) OSSwapHostToLittleInt64(x)
#define be64toh(x) OSSwapBigToHostInt64(x)
#define le64toh(x) OSSwapLittleToHostInt64(x)

#define __BYTE_ORDER    BYTE_ORDER
#define __BIG_ENDIAN    BIG_ENDIAN
#define __LITTLE_ENDIAN LITTLE_ENDIAN
#define __PDP_ENDIAN    PDP_ENDIAN
#endif

extern "C"
{
  extern wallaroo::SourceDecoder *get_order_source_decoder()
  {
    return new OrderSourceDecoder();
  }

  extern wallaroo::SourceDecoder *get_nbbo_source_decoder()
  {
    return new NbboSourceDecoder();
  }

  extern wallaroo::PartitionFunctionU64 *get_partition_function()
  {
    return new SymbolPartitionFunction();
  }

  extern wallaroo::StateComputation *get_check_order_no_update_no_output()
  {
    return new CheckOrderNoUpdateNoOutput();
  }

  extern wallaroo::StateComputation *get_update_nbbo_no_update_no_output()
  {
    return new UpdateNbboNoUpdateNoOutput();
  }

  extern wallaroo::StateComputation *get_check_order_no_output()
  {
    return new CheckOrderNoOutput();
  }

  extern wallaroo::StateComputation *get_update_nbbo_no_output()
  {
    return new UpdateNbboNoOutput();
  }

  extern wallaroo::StateComputation *get_check_order()
  {
    return new CheckOrder();
  }

  extern wallaroo::StateComputation *get_update_nbbo()
  {
    return new UpdateNbbo();
  }

  extern wallaroo::SinkEncoder *get_order_result_sink_encoder()
  {
    return new OrderResultSinkEncoder();
  }

  extern wallaroo::State *get_symbol_data()
  {
    return new SymbolData();
  }

  extern wallaroo::Serializable *w_user_serializable_deserialize(char *bytes_, size_t sz_)
  {
    return nullptr;
  }
}

// Buffer

Reader::Reader(unsigned char *bytes_): _ptr(bytes_)
{
}

uint8_t Reader::u8_be()
{
  uint8_t ret = *((uint8_t *)_ptr);
  _ptr += 1;
  return ret;
}

uint16_t Reader::u16_be()
{
  uint16_t ret = be16toh(*((uint16_t *)_ptr));
  _ptr += 2;
  return ret;
}

uint32_t Reader::u32_be()
{
  uint32_t ret = be32toh(*((uint32_t *)_ptr));
  _ptr += 4;
  return ret;
}

uint64_t Reader::u64_be()
{
  uint64_t ret = be64toh(*((uint64_t *)_ptr));
  _ptr += 8;
  return ret;
}

double Reader::ms_double()
{
  double ret = 0.0;
  char *p = (char *)(&ret) + 8;

  for (int i = 0; i < sizeof(double); i++)
  {
    *(--p) = *(_ptr++);
  }

  return ret;
}

string *Reader::ms_string(size_t sz_)
{
  string *ret = new string((char *)_ptr, sz_);
  _ptr += sz_;
  return ret;
}

Writer::Writer(unsigned char *bytes_): _ptr(bytes_)
{
}

void Writer::u8_be(uint8_t value_)
{
  *(uint8_t *)(_ptr) = value_;
  _ptr += 1;
}

void Writer::u16_be(uint16_t value_)
{
  *(uint16_t *)(_ptr) = htobe16(value_);
  _ptr += 2;
}

void Writer::u32_be(uint32_t value_)
{
  *(uint32_t *)(_ptr) = htobe32(value_);
  _ptr += 4;
}

void Writer::u64_be(uint64_t value_)
{
  *(uint64_t *)(_ptr) = htobe64(value_);
  _ptr += 8;
}

void Writer::ms_double(double value_)
{
  char *p = (char *)(&value_) + 8;

  for (int i = 0; i < sizeof(double); i++)
  {
    *(_ptr++) = *(--p);
  }
}

void Writer::ms_string(string *str) {
  std::memcpy(_ptr, str->c_str(), str->size());
  _ptr += str->size();
}

// Market Spread

size_t OrderSourceDecoder::header_length()
{
  return 4;
}

size_t OrderSourceDecoder::payload_length(char *bytes)
{
  Reader reader((unsigned char*) bytes);
  return reader.u32_be();
}

wallaroo::Data *OrderSourceDecoder::decode(char *bytes, size_t sz_)
{
  Reader reader((unsigned char*) bytes);

  uint8_t fix_type = reader.u8_be();
  if (fix_type != FixType::Order)
  {
    std::cerr << "wrong type! expected order, got fix_type=" << (uint16_t)fix_type << std::endl;
    return nullptr;
  }

  SideType side = (SideType) reader.u8_be();
  uint32_t account = reader.u32_be();
  string *order_id = reader.ms_string(6);
  string *symbol = reader.ms_string(4);
  double order_quantity = reader.ms_double();
  double price = reader.ms_double();
  string *transact_time = reader.ms_string(21);

  OrderMessage *order_message = new OrderMessage(side, account, *order_id, *symbol, order_quantity, price, *transact_time);

  delete order_id;
  delete symbol;
  delete transact_time;

  return order_message;
}

size_t NbboSourceDecoder::header_length()
{
  return 4;
}

size_t NbboSourceDecoder::payload_length(char *bytes)
{
  Reader reader((unsigned char*) bytes);
  return reader.u32_be();
}

wallaroo::Data *NbboSourceDecoder::decode(char *bytes, size_t sz_)
{
  Reader reader((unsigned char*) bytes);

  uint8_t fix_type = reader.u8_be();
  if (fix_type != FixType::Nbbo)
  {
    std::cerr << "wrong type! expected nbbo, got fix_type=" << fix_type << std::endl;
    return nullptr;
  }

  string *symbol = reader.ms_string(4);
  string *transact_time = reader.ms_string(21);
  double bid_price = reader.ms_double();
  double offer_price = reader.ms_double();

  // std::cerr << "bid_price=" << bid_price << " offer_price=" << offer_price << std::endl;

  NbboMessage *nbbo_message = new NbboMessage(*symbol, *transact_time, bid_price, offer_price);

  delete symbol;
  delete transact_time;

  return nbbo_message;
}

OrderMessage::OrderMessage(SideType side_, uint32_t account_,
                           string& order_id_, string& symbol_,
                           double order_quantity_, double price_,
                           string& transact_time_):
  _side(side_), _account(account_), _order_id(order_id_),
  _symbol(symbol_), _order_quantity(order_quantity_), _price(price_),
  _transact_time(transact_time_)
{
}

OrderMessage::OrderMessage(OrderMessage *that_):
  _side(that_->_side), _account(that_->_account), _order_id(that_->_order_id),
  _symbol(that_->_symbol), _order_quantity(that_->_order_quantity), _price(that_->_price),
  _transact_time(that_->_transact_time)
{
}

uint64_t partition_from_symbol(string& symbol_)
{
  uint64_t ret = 0;
  for (size_t i = 0; i < symbol_.size(); i++)
  {
    ret += ((unsigned char)symbol_[i]) << (i * 8);
  }

  return ret;
}

uint64_t OrderMessage::get_partition()
{
  return partition_from_symbol(_symbol);
}

NbboMessage::NbboMessage(string& symbol_, string& transit_time_, double bid_price_, double offer_price_):
  _symbol(symbol_), _transit_time(transit_time_), _bid_price(bid_price_), _offer_price(offer_price_)
{
}

uint64_t NbboMessage::get_partition()
{
  return partition_from_symbol(_symbol);
}

SymbolDataStateChange::SymbolDataStateChange(uint64_t id_): StateChange(id_), _should_reject_trades(false), _last_bid(0), _last_offer(0)
{
}

const char *SymbolDataStateChange::name()
{
  return "symbol data state change";
}

void SymbolDataStateChange::apply(wallaroo::State *state)
{
  SymbolData *symbol_data = (SymbolData *) state;
  symbol_data->should_reject_trades = _should_reject_trades;
  symbol_data->last_bid = _last_bid;
  symbol_data->last_offer = _last_offer;
}

void SymbolDataStateChange::update(bool should_reject_trades_, double last_bid_, double last_offer_)
{
  _should_reject_trades = should_reject_trades_;
  _last_bid = last_bid_;
  _last_offer = last_offer_;
}

wallaroo::StateChange *SymbolDataStateChangeBuilder::build(uint64_t id_)
{
  return new SymbolDataStateChange(id_);
}

uint64_t SymbolPartitionFunction::partition(wallaroo::Data *data_)
{
  PartitionableMessage *pm = (PartitionableMessage *) data_;
  return pm->get_partition();
}

void *CheckOrderNoUpdateNoOutput::compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void *state_change_repository_helper_, wallaroo::State *state_, void *none)
{
  return w_stateful_computation_get_return(state_change_repository_helper_, nullptr, none);
}

void *CheckOrderNoOutput::compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void *state_change_repository_helper_, wallaroo::State *state_, void *none)
{
  return w_stateful_computation_get_return(state_change_repository_helper_, nullptr, none);
}

void *CheckOrder::compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void *state_change_repository_helper_, wallaroo::State *state_, void *none)
{
  OrderMessage *order_message = (OrderMessage *) input_;

  SymbolData *symbol_data = (SymbolData *) state_;

  if (symbol_data->should_reject_trades)
  {
    // std::cerr << "rejected" << std::endl;
    // TODO: not getting time here, is this a problem?
    OrderResult *order_result = new OrderResult(order_message, symbol_data->last_bid, symbol_data->last_offer, 0);
    return w_stateful_computation_get_return(state_change_repository_helper_, order_result, none);
  }

  return w_stateful_computation_get_return(state_change_repository_helper_, nullptr, none);
}

void *UpdateNbboNoUpdateNoOutput::compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void *state_change_repository_helper_, wallaroo::State *state_, void *none)
{
  return w_stateful_computation_get_return(state_change_repository_helper_, nullptr, none);
}

void *UpdateNbboNoOutput::compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void *state_change_repository_helper_, wallaroo::State *state_, void *none)
{
  NbboMessage *nbbo_message = (NbboMessage *) input_;

  void *state_change_handle = w_state_change_repository_lookup_by_name(state_change_repository_helper_, state_change_repository_, "symbol data state change");

  SymbolDataStateChange *symbol_data_state_change = (SymbolDataStateChange *)w_state_change_get_state_change_object(state_change_repository_helper_, state_change_handle);


  double offer_bid_difference = nbbo_message->offer_price() - nbbo_message->bid_price();

  bool should_reject_trades = (offer_bid_difference >= 0.05) || ((offer_bid_difference / nbbo_message->mid()) >= 0.05);

  symbol_data_state_change->update(should_reject_trades, nbbo_message->bid_price(), nbbo_message->offer_price());

  return w_stateful_computation_get_return(state_change_repository_helper_, nullptr, state_change_handle);
}

void *UpdateNbbo::compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void *state_change_repository_helper_, wallaroo::State *state_, void *none)
{
  NbboMessage *nbbo_message = (NbboMessage *) input_;

  void *state_change_handle = w_state_change_repository_lookup_by_name(state_change_repository_helper_, state_change_repository_, "symbol data state change");

  SymbolDataStateChange *symbol_data_state_change = (SymbolDataStateChange *)w_state_change_get_state_change_object(state_change_repository_helper_, state_change_handle);


  double offer_bid_difference = nbbo_message->offer_price() - nbbo_message->bid_price();

  bool should_reject_trades = (offer_bid_difference >= 0.05) || ((offer_bid_difference / nbbo_message->mid()) >= 0.05);

  symbol_data_state_change->update(should_reject_trades, nbbo_message->bid_price(), nbbo_message->offer_price());

  return w_stateful_computation_get_return(state_change_repository_helper_, nullptr, state_change_handle);
}

OrderResult::OrderResult(OrderMessage *order_message_, double bid_, double offer_, uint64_t timestamp_): bid(bid_), offer(offer_), timestamp(timestamp_)
{
  order_message = new OrderMessage(order_message_);
}

OrderResult::~OrderResult()
{
  delete order_message;
}

size_t OrderResult::encode_get_size()
{
  return 55;
}

void OrderResult::encode(char *bytes)
{
  Writer writer((unsigned char *) bytes);

  switch (order_message->side())
  {
  case SideType::Buy:
    writer.u8_be((uint8_t) SideType::Buy);
    break;
  case SideType::Sell:
    writer.u8_be((uint8_t) SideType::Sell);
    break;
  default:
    std::cerr << "expected side to be buy or sell (1 or 2), but got side=" << order_message->side() << std::endl;
    writer.u8_be(0xFF);
    break;
  }

  writer.u32_be(order_message->account());
  writer.ms_string(order_message->order_id());
  writer.ms_string(order_message->symbol());
  writer.ms_double(order_message->order_quantity());
  writer.ms_double(order_message->price());
  writer.ms_double(bid);
  writer.ms_double(offer);
  writer.u64_be(timestamp);
}

size_t OrderResultSinkEncoder::get_size(wallaroo::EncodableData *data)
{
  //Header (size == 55 bytes)
  return data->encode_get_size();
}

void OrderResultSinkEncoder::encode(wallaroo::EncodableData *data, char *bytes)
{
  Writer writer((unsigned char *) bytes);

  uint32_t message_size = data->encode_get_size();

  writer.u32_be(message_size);

  data->encode(bytes + 4);
}
