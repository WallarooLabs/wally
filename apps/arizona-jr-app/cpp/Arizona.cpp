#include "Arizona.hpp"
#include "WallarooCppApi/Serializable.hpp"
#include "WallarooCppApi/ApiHooks.hpp"
#include "WallarooCppApi/UserHooks.hpp"
#include "WallarooCppApi/Logger.hpp"

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

// Utility

wallaroo::Data *message_from_bytes(char *bytes_)
{
  Reader reader((unsigned char *)bytes_);
  uint16_t message_type = reader.u16_be();
  uint64_t message_id = reader.u64_be();

  char *remaining_bytes = bytes_ + 10;

  switch (message_type)
  {
  case MessageType::Config:
  {
    return new ConfigMessage(message_id);
  }
  case MessageType::Order:
  {
    OrderMessage *om = new OrderMessage(message_id);
    om->from_bytes(remaining_bytes);
    return om;
  }
  case MessageType::Cancel:
  {
    CancelMessage *cm = new CancelMessage(message_id);
    cm->from_bytes(remaining_bytes);
    return cm;
  }
  case MessageType::Execute:
  {
    ExecuteMessage *em = new ExecuteMessage(message_id);
    em->from_bytes(remaining_bytes);
    return em;
  }
  case MessageType::Admin:
  {
    AdminMessage *am = new AdminMessage(message_id);
    am->from_bytes(remaining_bytes);
    return am;
  }
  }
  std::cerr << "unknown message type: " << message_type << std::endl;
  return NULL;
}

wallaroo::Key *partition_key_from_bytes(char *bytes_)
{
  Reader reader((unsigned char *)bytes_);

  uint64_t value = reader.u64_be();

  return new ArizonaPartitionKey(value);
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

ConfigMessage::ConfigMessage(uint64_t message_id_): _message_id(message_id_)
{
}

ConfigMessage::~ConfigMessage()
{
}

OrderMessage::OrderMessage(uint64_t message_id_): _message_id(message_id_)
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

CancelMessage::CancelMessage(uint64_t message_id_): _message_id(message_id_)
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

ExecuteMessage::ExecuteMessage(uint64_t message_id_): _message_id(message_id_)
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

AdminMessage::AdminMessage(uint64_t message_id_): _message_id(message_id_)
{
}

AdminMessage::~AdminMessage()
{
  delete _client;
  delete _account;
}

void AdminMessage::from_bytes(char *bytes_)
{
  Reader reader((unsigned char *)bytes_);

  _request_type = reader.u16_be();
  _client = reader.arizona_string();
  _account = reader.arizona_string();
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
  size_t sz = 2 + // framing length
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

  writer.u16_be(encode_get_size());
  writer.u16_be(MessageType::Proceeds);
  writer.u64_be(_message_id);
  writer.arizona_string(_isin);
  writer.arizona_double(_open_long);
  writer.arizona_double(_open_short);
  writer.arizona_double(_filled_long);
  writer.arizona_double(_filled_short);
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
    case 0:
      return message_from_bytes(remaining_bytes);
    case 1:
      return new ArizonaStateComputation();
    case 2:
      return new ArizonaSinkEncoder();
    case 3:
      return partition_key_from_bytes(remaining_bytes);
    case 4:
      // TODO: deserialize the state change builders here
      std::cerr << "deserialization of state change builders is not implemented yet." << std::endl;
      return nullptr;
    case 5:
      return new ArizonaPartitionFunction();
    case SerializationType::DefaultComputation:
      return new ArizonaDefaultStateComputation();
    }
    // TODO: do something better here
    std::cerr << "Don't know how to deserialize type=" << serialized_type << std::endl;
    return nullptr;
  }
}

size_t ArizonaSourceDecoder::header_length()
{
  return 2;
}

size_t ArizonaSourceDecoder::payload_length(char *bytes)
{
  return ((size_t)(bytes[0]) << 8) + (size_t)(bytes[1]) - 2;
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

const char *ArizonaStateComputation::name()
{
  return "arizona state computation";
}

ArizonaStateComputation::ArizonaStateComputation() : _nProcessed(0)
{
  _logger = wallaroo::Logger::getLogger();
  _logger->info("ArizonaStateComputation::ArizonaStateComputation()");
}

void *ArizonaStateComputation::compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void *state_change_repository_helper_, wallaroo::State *state_, void *none)
{
  _nProcessed += 1;
  if ( _nProcessed % 10000 == 0  )
    _logger->info("Processed messages:{}", _nProcessed);

  ClientMessage* cm = dynamic_cast<ClientMessage*>(input_);
  if ( cm != nullptr )
  {
    int messageType = cm->get_message_type();
    uint64_t message_id = cm->get_message_id();
    if ( messageType  == 1 )
    {
      ProceedsMessage *proceeds_message = new ProceedsMessage(message_id, new string(), 0.0, 0.0, 0.0, 0.0);
      return w_stateful_computation_get_return(state_change_repository_helper_, proceeds_message, none);
    }

    else if ( messageType  == 2 )
    {
      ProceedsMessage *proceeds_message = new ProceedsMessage(message_id, new string(), 0.0, 0.0, 0.0, 0.0);
      return w_stateful_computation_get_return(state_change_repository_helper_, proceeds_message, none);
    }

    else if ( messageType  == 3 )
    {
      ProceedsMessage *proceeds_message = new ProceedsMessage(message_id, new string(), 0.0, 0.0, 0.0, 0.0);
      return w_stateful_computation_get_return(state_change_repository_helper_, proceeds_message, none);
    }

    else if ( messageType  == 4 )
    {
      ProceedsMessage *proceeds_message = new ProceedsMessage(message_id, new string(), 0.0, 0.0, 0.0, 0.0);
      return w_stateful_computation_get_return(state_change_repository_helper_, proceeds_message, none);
    }
  }

  return w_stateful_computation_get_return(state_change_repository_helper_, NULL, none);
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
    string *client = cm->get_client();
    return new ArizonaPartitionKey(std::stoul(client->c_str() + 4, nullptr));
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
  // std::cerr << "DEFAULT COMPUTE" << std::endl;
  if (OrderMessage *om = dynamic_cast<OrderMessage *>(input_))
  {
    uint64_t message_id = om->get_message_id();
    ProceedsMessage *proceeds_message = new ProceedsMessage(message_id, new string(*(om->get_isin())), 0.0, 0.0, 0.0, 0.0);
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
