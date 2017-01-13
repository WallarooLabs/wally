#include "ArizonaState.hpp"
#include "Arizona.hpp"
#include "WallarooCppApi/Serializable.hpp"
#include "WallarooCppApi/ApiHooks.hpp"
#include "WallarooCppApi/UserHooks.hpp"
#include "WallarooCppApi/Logger.hpp"

#include <iostream>
#include <cstring>
#include <sstream>

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

// Utility

int ncnt = 0;

uint32_t peek_client_id(char *data_)
{
  Reader reader((unsigned char *) data_);
  return reader.u32_be();
}

ClientMessage* message_from_bytes(char *bytes_)
{
  Reader reader((unsigned char *) bytes_);
  uint32_t client_id = reader.u32_be();
  uint16_t message_type = reader.u16_be();
  uint64_t message_id = reader.u64_be();

  char *remaining_bytes = bytes_ + sizeof(uint64_t) + sizeof(uint16_t) + sizeof(uint32_t);

  ClientMessage* cm = nullptr;
  switch (message_type)
  {
    case MessageType::Config:
      cm = new ConfigMessage(message_id, client_id);
      cm->from_bytes(remaining_bytes);
      break;

    case MessageType::Order:
      cm = new OrderMessage(message_id, client_id);
      cm->from_bytes(remaining_bytes);
      break;

    case MessageType::Cancel:
      cm = new CancelMessage(message_id, client_id);
      cm->from_bytes(remaining_bytes);
      break;

    case MessageType::Execute:
      cm = new ExecuteMessage(message_id, client_id);
      cm->from_bytes(remaining_bytes);
      break;

    case MessageType::Admin:
      cm = new AdminMessage(message_id, client_id);
      cm->from_bytes(remaining_bytes);
      break;

    default:
      break;
  }

  if (cm == nullptr)
  {
    wallaroo::Logger::getLogger()->critical("unknown message type:", message_type);
    std::cerr << "unknown message type: " << message_type << std::endl;
  }

  return cm;
}

wallaroo::Key *partition_key_from_bytes(char *bytes_)
{
  Reader reader((unsigned char *)bytes_);
  uint64_t value = reader.u64_be();
  return new ArizonaPartitionKey(value);
}

//StateChangeBuilder

wallaroo::StateChangeBuilder *state_change_builder_from_bytes(char *bytes_)
{
  Reader reader((unsigned char *)bytes_);
  uint16_t scb_type = reader.u16_be();
  //TODO: find a way to efficiently reuse ArizonaStateComputation::get_state_change_builder()
  switch (scb_type)
  {
    case StateChangeBuilderType::AddOrder:
      return new AddOrderStateChangeBuilder();
    case StateChangeBuilderType::CancelOrder:
      return new CancelOrderStateChangeBuilder();
    case StateChangeBuilderType::ExecuteOrder:
      return new ExecuteOrderStateChangeBuilder();
    case StateChangeBuilderType::CreateAggUnit:
      return new CreateAggUnitStateChangeBuilder();
  }
  // TODO: This should be an error
  return nullptr;
}

// Buffer

Reader::Reader(unsigned char *bytes_): _ptr(bytes_)
{
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

double Reader::arizona_double()
{
  double ret = 0.0;
  char *p = (char *)(&ret) + 8;

  for (int i = 0; i < sizeof(double); i++)
  {
    *(--p) = *(_ptr++);
  }

  return ret;
}

string *Reader::arizona_string()
{
  size_t sz = u16_be();
  string *ret = new string((char *)_ptr, sz);
  _ptr += sz;
  return ret;
}

Writer::Writer(unsigned char *bytes_): _ptr(bytes_)
{
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

void Writer::arizona_double(double value_)
{
  char *p = (char *)(&value_) + 8;

  for (int i = 0; i < sizeof(double); i++)
  {
    *(_ptr++) = *(--p);
  }
}

void Writer::arizona_string(string *str) {
  u16_be(str->size());
  std::memcpy(_ptr, str->c_str(), str->size());
  _ptr += str->size();
}

// Messages

ConfigMessage::ConfigMessage(uint64_t message_id_, uint32_t client_id_): _message_id(message_id_), _client_id(client_id_)
{
}

ConfigMessage::~ConfigMessage()
{
}

string ConfigMessage::str()
{
  stringstream out;
  out << "MSG_COFG[]";
  return out.str();
}

OrderMessage::OrderMessage(uint64_t message_id_, uint32_t client_id_) :
    _message_id(message_id_),
    _client_id(client_id_),
    _price(0.0),
    _quantity(0),
    _side(0),
    _order_type(0),
    _isin(nullptr),
    _account(nullptr),
    _client(nullptr),
    _order_id(nullptr)
{
}

OrderMessage::~OrderMessage()
{
  delete _client;
  delete _account;
  delete _isin;
  delete _order_id;
}

void OrderMessage::from_bytes(char *bytes_)
{
  Reader reader((unsigned char *)bytes_);

  _client = reader.arizona_string();
  _account = reader.arizona_string();
  _isin = reader.arizona_string();
  _order_id = reader.arizona_string();
  _order_type = reader.u16_be();
  _side = reader.u16_be();
  _quantity = reader.u32_be();
  _price = reader.arizona_double();
}

void OrderMessage::serialize(char* bytes_, size_t nsz_)
{
  Writer writer((unsigned char *)bytes_);

  writer.u16_be(SerializationType::Message);
  writer.u16_be(MessageType::Order);

  writer.u64_be(_message_id);
  writer.arizona_string(_client);
  writer.arizona_string(_account);
  writer.arizona_string(_isin);
  writer.arizona_string(_order_id);
  writer.u16_be(_order_type);
  writer.u16_be(_side);
  writer.u32_be(_quantity);
  writer.arizona_double(_price);
}

size_t OrderMessage::serialize_get_size()
{
  size_t sz = 2 + // object type
    2 + // message type
    8 + // message id
    2 + _client->size() +
    2 + _account->size() +
    2 + _isin->size() +
    2 + _order_id->size() +
    2 + // order type
    2 + // side
    4 + // quantity
    8; // _price
  return sz;
}

string OrderMessage::str()
{
  stringstream out;
  out << "MSG_ORDR[";
  out << "id:" << _message_id;
  out << ",clnt:" << _client->c_str();
  out << ",acct:" << _account->c_str();
  out << ",isin:" << _isin->c_str();
  out << ",ooid:" << _order_id;
  out << ",qty:" << _quantity;
  out << ",prc:" << _price;
  out << "]";
  return out.str();
}


CancelMessage::CancelMessage(uint64_t message_id_, uint32_t client_id_): _message_id(message_id_), _client_id(client_id_)
{
}

CancelMessage::~CancelMessage()
{
  delete _client;
  delete _account;
  delete _order_id;
  delete _cancel_id;
}

void CancelMessage::from_bytes(char *bytes_)
{
  Reader reader((unsigned char *)bytes_);

  _client = reader.arizona_string();
  _account = reader.arizona_string();
  _order_id = reader.arizona_string();
  _cancel_id = reader.arizona_string();
}

void CancelMessage::serialize(char* bytes_, size_t nsz_)
{
  Writer writer((unsigned char *)bytes_);

  writer.u16_be(SerializationType::Message);
  writer.u16_be(MessageType::Cancel);

  writer.u64_be(_message_id);
  writer.arizona_string(_client);
  writer.arizona_string(_account);
  writer.arizona_string(_order_id);
  writer.arizona_string(_cancel_id);
}

size_t CancelMessage::serialize_get_size()
{
  size_t sz = 2 + // object type
    2 + // message type
    8 + // message id
    2 + _client->size() +
    2 + _account->size() +
    2 + _order_id->size() +
    2 + _cancel_id->size();
  return sz;
}

string CancelMessage::str()
{
  stringstream out;
  out << "MSG_CNCL[";
  out << "id:" << _message_id;
  out << ",clnt:" << _client->c_str();
  out << ",acct:" << _account->c_str();
  out << ",ooid:" << _order_id->c_str();
  out << ",cid:" << _cancel_id->c_str();
  out << "]";
  return out.str();
}

ExecuteMessage::ExecuteMessage(uint64_t message_id_, uint32_t client_id_): _message_id(message_id_), _client_id(client_id_)
{
}

ExecuteMessage::~ExecuteMessage()
{
  delete _client;
  delete _account;
  delete _order_id;
  delete _execution_id;
}

void ExecuteMessage::from_bytes(char *bytes_)
{
  Reader reader((unsigned char *)bytes_);

  _client = reader.arizona_string();
  _account = reader.arizona_string();
  _order_id = reader.arizona_string();
  _execution_id = reader.arizona_string();
  _quantity = reader.u32_be();
  _price = reader.arizona_double();
}

void ExecuteMessage::serialize(char* bytes_, size_t nsz_)
{
  Writer writer((unsigned char *)bytes_);

  writer.u16_be(SerializationType::Message);
  writer.u16_be(MessageType::Execute);

  writer.u64_be(_message_id);
  writer.arizona_string(_client);
  writer.arizona_string(_account);
  writer.arizona_string(_order_id);
  writer.arizona_string(_execution_id);
  writer.u32_be(_quantity);
  writer.arizona_double(_price);
}

size_t ExecuteMessage::serialize_get_size()
{
  size_t sz = 2 + // object type
    2 + // message type
    8 + // message id
    2 + _client->size() +
    2 + _account->size() +
    2 + _order_id->size() +
    2 + _execution_id->size() +
    4 + // quantity
    8; // price
  return sz;
}

string ExecuteMessage::str()
{
  stringstream out;
  out << "MSG_EXEC[";
  out << "id:" << _message_id;
  out << ",clnt:"<< _client->c_str();
  out << ",acct:"<< _account->c_str();
  out << ",ooid:"<<_order_id->c_str();
  out << ",eid:"<<_execution_id->c_str();
  out << "]";
  return out.str();
}

AdminMessage::AdminMessage(uint64_t message_id_, uint32_t client_id_): _message_id(message_id_), _client_id(client_id_)
{
}

AdminMessage::~AdminMessage()
{
  delete _client;
  delete _account;
  delete _aggunit;
}

void AdminMessage::from_bytes(char *bytes_)
{
  Reader reader((unsigned char *)bytes_);

  _request_type = (AdminRequestType) reader.u16_be();
  _client = reader.arizona_string();
  _account = reader.arizona_string();
  _aggunit = reader.arizona_string();
}

void AdminMessage::serialize(char* bytes_, size_t nsz_)
{
  Writer writer((unsigned char *)bytes_);

  writer.u16_be(SerializationType::Message);
  writer.u16_be(MessageType::Admin);

  writer.u64_be(_message_id);
  writer.u16_be(_request_type);
  writer.arizona_string(_client);
  writer.arizona_string(_account);
  writer.arizona_string(_aggunit);
}

size_t AdminMessage::serialize_get_size()
{
  size_t sz = 2 + // object type
    2 + // message type
    8 + // message id
    2 + // request type
    2 + _client->size() +
    2 + _account->size();
  return sz;
}

string AdminMessage::str()
{
  stringstream out;
  out << "MSG_ADMN[";
  out << "type:" << _request_type;
  out << ",id:" << _message_id;
  out << ",clnt:"<< _client->c_str();
  out << ",acct:"<< _account->c_str();
  out << "]";
  return out.str();
}

ProceedsMessage::ProceedsMessage(uint64_t message_id_, string *isin_,
                                 double open_long_, double open_short_,
                                 double filled_long_, double filled_short_):
  _message_id(message_id_),
  _isin(isin_),
  _open_long(open_long_),
  _open_short(open_short_),
  _filled_long(filled_long_),
  _filled_short(filled_short_)
{
}

ProceedsMessage::~ProceedsMessage()
{
  delete _isin;
}

size_t ProceedsMessage::encode_get_size()
{
  size_t sz = 4 + // framing length
    2 + // message type
    8 + // message id
    2 + // _isin size
    _isin->size() + // isin characters
    8 + // open long
    8 + // open short
    8 + // filled long
    8;  // filed short
  return sz;
}

void ProceedsMessage::encode(char *bytes)
{
  Writer writer((unsigned char *)bytes);

  writer.u32_be(encode_get_size() - 4);
  writer.u16_be(MessageType::Proceeds);
  writer.u64_be(_message_id);
  writer.arizona_string(_isin);
  writer.arizona_double(_open_long);
  writer.arizona_double(_open_short);
  writer.arizona_double(_filled_long);
  writer.arizona_double(_filled_short);
}

size_t AdminResponseMessage::encode_get_size()
{
  size_t sz = 4 + // framing length
    2 + // message type
    2; // response type
  return sz;
}

void AdminResponseMessage::encode(char *bytes)
{
  Writer writer((unsigned char *)bytes);

  writer.u32_be(encode_get_size() - 4);
  writer.u16_be(MessageType::AdminResponse);
  writer.u16_be(_response);
}

// Arizona

extern "C" {
  extern uint64_t get_partition_key(uint64_t value_)
  {
    return value_;
  }

  extern wallaroo::PartitionFunctionU64* get_partition_function()
  {
    return new ArizonaPartitionFunction();
  }

  extern wallaroo::SourceDecoder *get_source_decoder()
  {
    return new ArizonaSourceDecoder();
  }

  extern wallaroo::SinkEncoder *get_sink_encoder()
  {
    return new ArizonaSinkEncoder();
  }

  extern wallaroo::Computation *get_computation()
  {
    return new PassThroughComputation();
  }

  extern wallaroo::StateComputation *get_state_computation()
  {
    return new ArizonaStateComputation();
  }

  extern wallaroo::StateComputation *get_default_state_computation()
  {
    return new ArizonaDefaultStateComputation();
  }

  extern wallaroo::State *get_state()
  {
    return new ArizonaState();
  }

  extern wallaroo::State *get_default_state()
  {
    return new ArizonaDefaultState();
  }

  extern wallaroo::Serializable *w_user_serializable_deserialize(char *bytes_, size_t sz_)
  {
    Reader reader((unsigned char *)bytes_);

    uint16_t serialized_type = reader.u16_be();

    char *remaining_bytes = bytes_ + 2;

    switch(serialized_type)
    {
      case SerializationType::Message:
        return message_from_bytes(remaining_bytes);
      case SerializationType::Computation:
        return new ArizonaStateComputation();
      case SerializationType::SinkEncoder:
        return new ArizonaSinkEncoder();
      case SerializationType::PartitionKey:
        return partition_key_from_bytes(remaining_bytes);
      case SerializationType::StateChangeBuilder:
        return state_change_builder_from_bytes(remaining_bytes);
      case SerializationType::PartitionFunction:
        return new ArizonaPartitionFunction();
      case SerializationType::DefaultComputation:
        return new ArizonaDefaultStateComputation();
      case SerializationType::SourceDecoder:
        return new ArizonaSourceDecoder();
    }
    // TODO: do something better here
    std::cerr << "Don't know how to deserialize type=" << serialized_type << std::endl;
    return nullptr;
  }
}

size_t ArizonaSourceDecoder::header_length()
{
  return 4;
}

size_t ArizonaSourceDecoder::payload_length(char *bytes)
{
  return ((size_t)(bytes[0]) << 24) +
         ((size_t)(bytes[1]) << 16) +
         ((size_t)(bytes[2]) << 8) +
         ((size_t)(bytes[3]) << 0);
}

wallaroo::Data *ArizonaSourceDecoder::decode(char *bytes, size_t sz_)
{
  return message_from_bytes(bytes);
}

size_t ArizonaSinkEncoder::get_size(wallaroo::EncodableData *data)
{
  return data->encode_get_size();
}

void ArizonaSinkEncoder::encode(wallaroo::EncodableData *data, char *bytes)
{
  data->encode(bytes);
}

class Proceeds ArizonaState::proceeds_with_order(string& client_id_, string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  return _clients.proceeds_with_order(client_id_, account_id_, isin_id_, order_id_, side_, quantity_, price_);
}

void ArizonaState::add_order(string& client_id_, string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  _clients.add_order(client_id_, account_id_, isin_id_, order_id_, side_, quantity_, price_);
}

class Proceeds ArizonaState::proceeds_with_cancel(string& client_id_, string& account_id_, string& order_id_)
{
  return _clients.proceeds_with_cancel(client_id_, account_id_, order_id_);
}

void ArizonaState::cancel_order(string& client_id_, string& account_id_, string& order_id_)
{
  _clients.cancel_order(client_id_, account_id_, order_id_);
}

class Proceeds ArizonaState::proceeds_with_execute(string& client_id_, string& account_id_, string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  return _clients.proceeds_with_execute(client_id_, account_id_, order_id_, execution_id_, quantity_, price_);
}

void ArizonaState::execute_order(string& client_id_, string& account_id_, string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  _clients.execute(client_id_, account_id_, order_id_, execution_id_, quantity_, price_);
}

void ArizonaState::create_agg_unit(string& client_id_, string& agg_unit_id_)
{
  _clients.create_agg_unit(client_id_, agg_unit_id_);
}

class Proceeds ArizonaState::proceeds_for_agg_unit(string& client_id_, string& agg_unit_id_)
{
  return _clients.proceeds_for_agg_unit(client_id_, agg_unit_id_);
}

void ArizonaState::add_account_to_agg_unit(string& client_id_, string& account_id_, string& agg_unit_id_)
{
  _clients.add_account_to_agg_unit(client_id_, account_id_, agg_unit_id_);
}

void ArizonaState::remove_account_from_agg_unit(string& client_id_, string& account_id_, string& agg_unit_id_)
{
  _clients.remove_account_from_agg_unit(client_id_, account_id_, agg_unit_id_);
}

AddOrderStateChange::AddOrderStateChange(uint64_t id_): StateChange(id_), _client_id(), _account_id(), _isin_id(), _order_id(), _quantity(0), _price(0.0)
{
}

void AddOrderStateChange::update(string& client_id_, string& account_id_, string& isin_id_, string& order_id_, uint16_t side_, uint32_t quantity_, double price_)
{
  //wallaroo::Logger::getLogger()->critical("update state change");
  _client_id = client_id_;
  _account_id = account_id_;
  _isin_id = isin_id_;
  _order_id = order_id_;
  _side = (Side) side_;
  _quantity = quantity_;
  _price = price_;
}

void AddOrderStateChange::apply(wallaroo::State *state_)
{
  //wallaroo::Logger::getLogger()->critical("apply state change");
  ArizonaState *az_state = (ArizonaState *)state_;
  az_state->add_order(_client_id, _account_id, _isin_id, _order_id, _side, _quantity, _price);
}

void AddOrderStateChange::to_log_entry(char *bytes_)
{
  Writer writer((unsigned char *)bytes_);
  writer.u32_be(get_log_entry_size());
  writer.arizona_string(&_client_id);
  writer.arizona_string(&_account_id);
  writer.arizona_string(&_isin_id);
  writer.arizona_string(&_order_id);
  writer.u16_be(_side);
  writer.u32_be(_quantity);
  writer.arizona_double(_price);
}
size_t AddOrderStateChange::get_log_entry_size()
{
  return _client_id.size() +
  _account_id.size() +
  _isin_id.size() +
  _order_id.size() +
  sizeof(uint16_t) +
  sizeof(uint32_t) +
  sizeof(double);
}
size_t AddOrderStateChange::read_log_entry_size_header(char *bytes_)
{
  Reader reader((unsigned char *) bytes_);
  return reader.u32_be();
}
bool AddOrderStateChange::read_log_entry(char *bytes_)
{
  Reader reader((unsigned char *) bytes_);
  _client_id = *reader.arizona_string();
  _account_id = *reader.arizona_string();
  _isin_id = *reader.arizona_string();
  _order_id = *reader.arizona_string();
  _side = (Side) reader.u16_be();
  _quantity = reader.u32_be();
  _price = reader.arizona_double();
  return true;
}

CancelOrderStateChange::CancelOrderStateChange(uint64_t id_): StateChange(id_), _client_id(), _account_id(), _order_id()
{
}

void CancelOrderStateChange::to_log_entry(char *bytes_)
{
  Writer writer((unsigned char *)bytes_);
  writer.u32_be(get_log_entry_size());
  writer.arizona_string(&_client_id);
  writer.arizona_string(&_account_id);
  writer.arizona_string(&_order_id);
}
size_t CancelOrderStateChange::get_log_entry_size()
{
  return _client_id.size() +
  _account_id.size() +
  _order_id.size();
}
size_t CancelOrderStateChange::read_log_entry_size_header(char *bytes_)
{
  Reader reader((unsigned char *) bytes_);
  return reader.u32_be();
}
bool CancelOrderStateChange::read_log_entry(char *bytes_)
{
  Reader reader((unsigned char *) bytes_);
  _client_id = *reader.arizona_string();
  _account_id = *reader.arizona_string();
  _order_id = *reader.arizona_string();
  return true;
}

void CancelOrderStateChange::update(string& client_id_, string& account_id_, string& order_id_)
{
  _client_id = client_id_;
  _account_id = account_id_;
  _order_id = order_id_;
}

void CancelOrderStateChange::apply(wallaroo::State *state_)
{
  //wallaroo::Logger::getLogger()->critical("apply state change");
  ArizonaState *az_state = (ArizonaState *)state_;
  az_state->cancel_order(_client_id, _account_id, _order_id);
}

ExecuteOrderStateChange::ExecuteOrderStateChange(uint64_t id_):
  StateChange(id_), _client_id(), _account_id(), _order_id(), _execution_id(), _quantity(0), _price(0.0)
{
}

void ExecuteOrderStateChange::update(string& client_id_, string& account_id_, string& order_id_, string& execution_id_, uint32_t quantity_, double price_)
{
  _client_id = client_id_;
  _account_id = account_id_;
  _order_id = order_id_;
  _execution_id = execution_id_;
  _quantity = quantity_;
  _price = price_;
}

void ExecuteOrderStateChange::to_log_entry(char *bytes_)
{
  Writer writer((unsigned char *)bytes_);
  writer.u32_be(get_log_entry_size());
  writer.arizona_string(&_client_id);
  writer.arizona_string(&_account_id);
  writer.arizona_string(&_order_id);
  writer.arizona_string(&_execution_id);
  writer.u32_be(_quantity);
  writer.arizona_double(_price);
}

size_t ExecuteOrderStateChange::get_log_entry_size()
{
  return _client_id.size() +
  _account_id.size() +
  _order_id.size() +
  _execution_id.size() +
  sizeof(uint32_t) +
  sizeof(double);
}

size_t ExecuteOrderStateChange::read_log_entry_size_header(char *bytes_)
{
  Reader reader((unsigned char *) bytes_);
  return reader.u32_be();
}
bool ExecuteOrderStateChange::read_log_entry(char *bytes_)
{
  Reader reader((unsigned char *) bytes_);
  _client_id = *reader.arizona_string();
  _account_id = *reader.arizona_string();
  _order_id = *reader.arizona_string();
  _execution_id = *reader.arizona_string();
  _quantity = reader.u32_be();
  _price = reader.arizona_double();
  return true;
}

void ExecuteOrderStateChange::apply(wallaroo::State *state_)
{
  ArizonaState *az_state = (ArizonaState *)state_;
  az_state->execute_order(_client_id, _account_id, _order_id, _execution_id, _quantity, _price);
}

CreateAggUnitStateChange::CreateAggUnitStateChange(uint64_t id_):
  StateChange(id_), _client_id(), _agg_unit_id()
{
}

void CreateAggUnitStateChange::update(string& client_id_, string& agg_unit_id_)
{
  _client_id = client_id_;
  _agg_unit_id = agg_unit_id_;
}

void CreateAggUnitStateChange::to_log_entry(char *bytes_)
{
  Writer writer((unsigned char *)bytes_);
  writer.u32_be(get_log_entry_size());
  writer.arizona_string(&_client_id);
  writer.arizona_string(&_agg_unit_id);
}

size_t CreateAggUnitStateChange::get_log_entry_size()
{
  return 2 + _client_id.size() +
    2 + _agg_unit_id.size();
}

size_t CreateAggUnitStateChange::read_log_entry_size_header(char *bytes_)
{
  Reader reader((unsigned char *) bytes_);
  return reader.u32_be();
}
bool CreateAggUnitStateChange::read_log_entry(char *bytes_)
{
  Reader reader((unsigned char *) bytes_);
  _client_id = *reader.arizona_string();
  _agg_unit_id = *reader.arizona_string();
  return true;
}

void CreateAggUnitStateChange::apply(wallaroo::State *state_)
{
  ArizonaState *az_state = (ArizonaState *)state_;
  az_state->create_agg_unit(_client_id, _agg_unit_id);
}

class Proceeds ArizonaDefaultState::proceeds_with_order(string& client_id_, string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_)
{
  return _clients.proceeds_with_order(client_id_, account_id_, isin_id_, order_id_, side_, quantity_, price_);
}

const char *ArizonaStateComputation::name()
{
  return "arizona state computation";
}

ArizonaStateComputation::ArizonaStateComputation() : _nProcessed(0)
{
  _logger = wallaroo::Logger::getLogger();
  if ( ncnt <= 1 )
    _logger->info("{}", __PRETTY_FUNCTION__);
}

void *ArizonaStateComputation::compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void *state_change_repository_helper_, wallaroo::State *state_, void *none)
{
  // wallaroo::Logger::getLogger()->critical("COMPUTE");
  if (OrderMessage *om = dynamic_cast<OrderMessage *>(input_))
  {
    ArizonaState *az_state = (ArizonaState*) state_;

    class Proceeds proceeds = az_state->proceeds_with_order(*om->get_client(),
                                                            *om->get_account(),
                                                            *om->get_isin(),
                                                            *om->get_order_id(),
                                                            (Side) om->get_side(),
                                                            om->get_quantity(),
                                                            om->get_price());

    ProceedsMessage *proceeds_message = new ProceedsMessage(om->get_message_id(),
                                                            new string(*om->get_isin()),
                                                            proceeds.open_short(),
                                                            proceeds.open_long(),
                                                            proceeds.proceeds_short(),
                                                            proceeds.proceeds_long());

    void *state_change_handle = w_state_change_repository_lookup_by_name(state_change_repository_helper_, state_change_repository_, "add order state change");

    AddOrderStateChange *add_order_state_change = (AddOrderStateChange *)w_state_change_get_state_change_object(state_change_repository_helper_, state_change_handle);

    add_order_state_change->update(*om->get_client(),
                                   *om->get_account(),
                                   *om->get_isin(),
                                   *om->get_order_id(),
                                   om->get_side(),
                                   om->get_quantity(),
                                   om->get_price());

    return w_stateful_computation_get_return(state_change_repository_helper_, proceeds_message, state_change_handle);
  }

  if (CancelMessage *cm = dynamic_cast<CancelMessage *>(input_))
  {
    uint64_t message_id = cm->get_message_id();

    ArizonaState *az_state = (ArizonaState*) state_;

    class Proceeds proceeds = az_state->proceeds_with_cancel(*cm->get_client(),
                                                            *cm->get_account(),
                                                            *cm->get_order_id());

    ProceedsMessage *proceeds_message = new ProceedsMessage(cm->get_message_id(),
                                                            new string(proceeds.isin()),
                                                            proceeds.open_short(),
                                                            proceeds.open_long(),
                                                            proceeds.proceeds_short(),
                                                            proceeds.proceeds_long());

    void *state_change_handle = w_state_change_repository_lookup_by_name(state_change_repository_helper_, state_change_repository_, "cancel order state change");

    CancelOrderStateChange *cancel_order_state_change = (CancelOrderStateChange *)w_state_change_get_state_change_object(state_change_repository_helper_, state_change_handle);

    cancel_order_state_change->update(*cm->get_client(),
                                      *cm->get_account(),
                                      *cm->get_order_id());

    return w_stateful_computation_get_return(state_change_repository_helper_, proceeds_message, state_change_handle);
  }

  if (ExecuteMessage *em = dynamic_cast<ExecuteMessage *>(input_))
  {
    uint64_t message_id = em->get_message_id();

    ArizonaState *az_state = (ArizonaState*) state_;

    class Proceeds proceeds = az_state->proceeds_with_execute(*em->get_client(),
                                                              *em->get_account(),
                                                              *em->get_order_id(),
                                                              *em->get_execution_id(),
                                                              em->get_quantity(),
                                                              em->get_price());

    ProceedsMessage *proceeds_message = new ProceedsMessage(em->get_message_id(),
                                                            new string(proceeds.isin()),
                                                            proceeds.open_short(),
                                                            proceeds.open_long(),
                                                            proceeds.proceeds_short(),
                                                            proceeds.proceeds_long());

    void *state_change_handle = w_state_change_repository_lookup_by_name(state_change_repository_helper_, state_change_repository_, "execute order state change");

    ExecuteOrderStateChange *execute_order_state_change = (ExecuteOrderStateChange *)w_state_change_get_state_change_object(state_change_repository_helper_, state_change_handle);

    execute_order_state_change->update(*em->get_client(),
                                       *em->get_account(),
                                       *em->get_order_id(),
                                       *em->get_execution_id(),
                                       em->get_quantity(),
                                       em->get_price());

    return w_stateful_computation_get_return(state_change_repository_helper_, proceeds_message, state_change_handle);
  }

  if (AdminMessage *am = dynamic_cast<AdminMessage *>(input_))
  {
    uint64_t message_id = am->get_message_id();
    switch(am->get_request_type())
    {
      case AdminRequestType::CreateAggUnitRequest:
      {
        //TODO: add aggunit to client
        void *state_change_handle = w_state_change_repository_lookup_by_name(
            state_change_repository_helper_,
            state_change_repository_,
            "create agg unit state change");
        CreateAggUnitStateChange *create_aggunit_state_change =
          (CreateAggUnitStateChange *) w_state_change_get_state_change_object(
              state_change_repository_helper_, state_change_handle);
        create_aggunit_state_change->update(*am->get_client(), *am->get_aggunit());
        AdminResponseMessage *response_message = 
          new AdminResponseMessage(am->get_message_id(), AdminResponseType::Ok);
        return w_stateful_computation_get_return(
            state_change_repository_helper_,
            response_message,
            state_change_handle);
      }
      break;
      case AdminRequestType::QueryAggUnit:
        //TODO: query aggunit
        break;
      case AdminRequestType::AddAggUnit:
        //TODO: add account to agguint
        break;
      case AdminRequestType::RemoveAggUnit:
        //TODO: delete account from aggunit
        break;
    }
    ProceedsMessage *proceeds_message = new ProceedsMessage(message_id, new string(), 0.0, 0.0, 0.0, 0.0);
    return w_stateful_computation_get_return(state_change_repository_helper_, proceeds_message, none);
  }

  return w_stateful_computation_get_return(state_change_repository_helper_, NULL, none);
}

wallaroo::StateChangeBuilder *ArizonaStateComputation::get_state_change_builder(size_t idx_)
{
  switch (idx_)
  {
    case StateChangeBuilderType::AddOrder:
      return new AddOrderStateChangeBuilder();
    case StateChangeBuilderType::CancelOrder:
      return new CancelOrderStateChangeBuilder();
    case StateChangeBuilderType::ExecuteOrder:
      return new ExecuteOrderStateChangeBuilder();
    case StateChangeBuilderType::CreateAggUnit:
      return new CreateAggUnitStateChangeBuilder();
  }
  // TODO: This should be an error
  return nullptr;
}

const char *PassThroughComputation::name()
{
  return "PassThroughComputation";
}

wallaroo::Data *PassThroughComputation::compute(wallaroo::Data *input_)
{
  return NULL;
}

// Partition

ArizonaPartitionKey::ArizonaPartitionKey(uint64_t value_): _value(value_)
{
}

uint64_t ArizonaPartitionKey::hash()
{
  return _value;
}

bool ArizonaPartitionKey::eq(wallaroo::Key *other_)
{
  ArizonaPartitionKey *apk = static_cast<ArizonaPartitionKey *>(other_);
  return _value == apk->_value;
}

void ArizonaPartitionKey::serialize(char *bytes_, size_t nsz_)
{
  Writer writer((unsigned char *)bytes_);
  writer.u16_be(SerializationType::PartitionKey);
  writer.u64_be(_value);
}

uint64_t ArizonaPartitionFunction::partition(wallaroo::Data *data_)
{
  if (ClientMessage *cm = dynamic_cast<ClientMessage *>(data_))
  {
    return cm->get_client_id();
  }
  // TODO: Really we should come up with a better plan here.
  std::cerr << "could not get a key for message" << std::endl;
  wallaroo::Logger::getLogger()->critical("could not get a key for message");
  return 0;
}

const char *ArizonaDefaultStateComputation::name()
{
  return "arizona default state computation";
}

void *ArizonaDefaultStateComputation::compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void *state_change_repository_helper_, wallaroo::State *state_, void *none)
{
  wallaroo::Logger::getLogger()->critical("DEFAULT COMPUTE");
  if (OrderMessage *om = dynamic_cast<OrderMessage *>(input_))
  {
    ArizonaState *az_state = (ArizonaState*) state_;
    OrderMessage *order_message = (OrderMessage*) input_;

    class Proceeds proceeds = az_state->proceeds_with_order(*order_message->get_client(),
                                                            *order_message->get_account(),
                                                            *order_message->get_isin(),
                                                            *order_message->get_order_id(),
                                                            (Side) order_message->get_side(),
                                                            order_message->get_quantity(),
                                                            order_message->get_price());

    ProceedsMessage *proceeds_message = new ProceedsMessage(order_message->get_message_id(),
                                                            order_message->get_isin(),
                                                            proceeds.open_short(),
                                                            proceeds.open_long(),
                                                            proceeds.proceeds_short(),
                                                            proceeds.proceeds_long());

    return w_stateful_computation_get_return(state_change_repository_helper_, proceeds_message, none);
  }

  if (CancelMessage *cm = dynamic_cast<CancelMessage *>(input_))
  {
    uint64_t message_id = cm->get_message_id();
    ProceedsMessage *proceeds_message = new ProceedsMessage(message_id, new string(), 0.0, 0.0, 0.0, 0.0);
    return w_stateful_computation_get_return(state_change_repository_helper_, proceeds_message, none);
  }

  if (ExecuteMessage *em = dynamic_cast<ExecuteMessage *>(input_))
  {
    uint64_t message_id = em->get_message_id();
    ProceedsMessage *proceeds_message = new ProceedsMessage(message_id, new string(), 0.0, 0.0, 0.0, 0.0);
    return w_stateful_computation_get_return(state_change_repository_helper_, proceeds_message, none);
  }

  if (AdminMessage *am = dynamic_cast<AdminMessage *>(input_))
  {
    uint64_t message_id = am->get_message_id();
    ProceedsMessage *proceeds_message = new ProceedsMessage(message_id, new string(), 0.0, 0.0, 0.0, 0.0);
    return w_stateful_computation_get_return(state_change_repository_helper_, proceeds_message, none);
  }


  return w_stateful_computation_get_return(state_change_repository_helper_, NULL, none);
}
