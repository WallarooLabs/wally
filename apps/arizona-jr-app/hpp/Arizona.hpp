#ifndef __ARIZONA_JR_HPP__
#define __ARIZONA_JR_HPP__

#include "WallarooCppApi/Serializable.hpp"
#include "WallarooCppApi/SourceDecoder.hpp"
#include "WallarooCppApi/SinkEncoder.hpp"
#include "WallarooCppApi/Computation.hpp"
#include "WallarooCppApi/State.hpp"
#include "WallarooCppApi/Data.hpp"
#include "WallarooCppApi/Key.hpp"
#include "WallarooCppApi/PartitionFunction.hpp"
#include <spdlog/spdlog.h>
#include <memory>

using namespace std;
using namespace spdlog;

// Buffer

class Reader
{
private:
  unsigned char *_ptr;
public:
  Reader(unsigned char *bytes_);
  uint16_t u16_be();
  uint32_t u32_be();
  uint64_t u64_be();
  double arizona_double();
  string *arizona_string();
};


class Writer
{
private:
  unsigned char *_ptr;
public:
  Writer(unsigned char *bytes_);
  void u16_be(uint16_t value_);
  void u32_be(uint32_t value_);
  void u64_be(uint64_t value_);
  void arizona_double(double value_);
  void arizona_string(string *str);
};

// Serialization

enum SerializationType
{
  Message = 0,
  Computation = 1,
  SinkEncoder = 2,
  PartitionKey = 3,
  StateChangeBuilder = 4,
  PartitionFunction = 5,
  DefaultComputation = 6
};

// Messages

enum MessageType
{
  Config = 0,
  Order = 1,
  Cancel = 2,
  Execute = 3,
  Admin = 4,
  Proceeds = 5
};

class ClientMessage
{
public:
  virtual string *get_client() = 0;
  virtual int get_message_type() = 0;
  virtual uint64_t get_message_id() = 0;
};

class ConfigMessage: public wallaroo::Data
{
private:
  uint64_t _message_id;
public:
  ConfigMessage(uint64_t _message_id);
  virtual ~ConfigMessage();
  uint64_t get_message_id() { return _message_id; }
  void from_bytes(char *bytes_) { }
};

class OrderMessage: public wallaroo::Data, public ClientMessage
{
private:
  uint64_t _message_id;
  string *_client;
  string *_account;
  string *_isin;
  string *_order_id;
  uint16_t _order_type;
  uint16_t _side;
  uint32_t _quantity;
  double _price;
public:
  OrderMessage(uint64_t _message_id);
  virtual ~OrderMessage();
  virtual string *get_client() { return _client; }
  virtual uint64_t get_message_id() { return _message_id; }
  string *get_isin() { return _isin; }
  void from_bytes(char *bytes_);
  virtual void serialize(char* bytes_, size_t nsz_);
  virtual size_t serialize_get_size();
  virtual int get_message_type() { return 1; }
};

class CancelMessage: public wallaroo::Data, public ClientMessage
{
private:
  uint16_t _message_id;
  string *_client;
  string *_account;
  string *_order_id;
  string *_cancel_id;
public:
  CancelMessage(uint64_t _message_id);
  virtual ~CancelMessage();
  virtual string *get_client() { return _client; }
  virtual uint64_t get_message_id() { return _message_id; }
  void from_bytes(char *bytes_);
  virtual void serialize(char* bytes_, size_t nsz_);
  virtual size_t serialize_get_size();
  virtual int get_message_type() { return 2; }
};

class ExecuteMessage: public wallaroo::Data, public ClientMessage
{
private:
  uint64_t _message_id;
  string *_client;
  string *_account;
  string *_order_id;
  string *_execution_id;
  uint32_t _quantity;
  double _price;
public:
  ExecuteMessage(uint64_t _message_id);
  virtual ~ExecuteMessage();
  virtual string *get_client() { return _client; }
  virtual uint64_t get_message_id() { return _message_id; }
  void from_bytes(char *bytes_);
  virtual void serialize(char* bytes_, size_t nsz_);
  virtual size_t serialize_get_size();
  virtual int get_message_type() { return 2; }
};

class AdminMessage: public wallaroo::Data, public ClientMessage
{
private:
  uint64_t _message_id;
  uint16_t _request_type;
  string *_client;
  string *_account;
public:
  AdminMessage(uint64_t message_id_);
  virtual ~AdminMessage();
  virtual string *get_client() { return _client; }
  virtual uint64_t get_message_id() { return _message_id; }
  void from_bytes(char *bytes);
  virtual void serialize(char* bytes_, size_t nsz_);
  virtual size_t serialize_get_size();
  virtual int get_message_type() { return 4; }
};

class ProceedsMessage: public wallaroo::EncodableData
{
private:
  uint64_t _message_id;
  string *_isin;
  double _open_long;
  double _open_short;
  double _filled_long;
  double _filled_short;
public:
  ProceedsMessage(uint64_t message_id_, string *isin_,
                  double open_long_, double open_short_,
                  double filled_long_, double filled_short_);
  ~ProceedsMessage();
  virtual size_t encode_get_size();
  virtual void encode(char *bytes);
};

// Arizona

class ArizonaSourceDecoder: public wallaroo::SourceDecoder
{
public:
  virtual size_t header_length();
  virtual size_t payload_length(char *bytes);
  virtual wallaroo::Data *decode(char *bytes, size_t sz_);
};

class ArizonaSinkEncoder: public wallaroo::SinkEncoder
{
public:
  virtual size_t get_size(wallaroo::EncodableData *data);
  virtual void encode(wallaroo::EncodableData *data, char *bytes);
  virtual void serialize (char* bytes_, size_t nsz_) { Writer writer((unsigned char *)bytes_); writer.u16_be(SerializationType::SinkEncoder); }
  virtual size_t serialize_get_size () { return 2; }
};

class ArizonaState: public wallaroo::State
{
public:
  ArizonaState() {};
};

class ArizonaDefaultState: public wallaroo::State
{
public:
  ArizonaDefaultState() {};
};

class ArizonaStateComputation: public wallaroo::StateComputation
{
private:
  size_t _nProcessed;
  shared_ptr<logger> _logger;

public:
  ArizonaStateComputation();
  virtual const char *name();
  virtual void *compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void* state_change_Respository_helper_, wallaroo::State *state_, void *none);
  virtual size_t get_number_of_state_change_builders() { return 0;}
  virtual wallaroo::StateChangeBuilder *get_state_change_builder(size_t idx_) { return NULL; }
  virtual void serialize(char* bytes_, size_t nsz_) { Writer writer((unsigned char *)bytes_); writer.u16_be(SerializationType::Computation); }
  virtual size_t serialize_get_size () { return 2; }
};

class ArizonaDefaultStateComputation: public wallaroo::StateComputation
{
public:
  virtual const char *name();
  virtual void *compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void* state_change_Respository_helper_, wallaroo::State *state_, void *none);
  virtual size_t get_number_of_state_change_builders() { return 0;}
  virtual wallaroo::StateChangeBuilder *get_state_change_builder(size_t idx_) { return NULL; }
  virtual void serialize(char* bytes_, size_t nsz_) { Writer writer((unsigned char *)bytes_); writer.u16_be(SerializationType::DefaultComputation); }
  virtual size_t serialize_get_size () { return 2; }
};

// Partitioning

class ArizonaPartitionKey: public wallaroo::Key
{
private:
  uint64_t _value;
public:
  ArizonaPartitionKey(uint64_t value_);
  virtual ~ArizonaPartitionKey() {}
  virtual uint64_t hash();
  virtual bool eq(wallaroo::Key *other_);
  virtual void serialize (char* bytes_, size_t nsz_);
  virtual size_t serialize_get_size () { return 10; }
};

class ArizonaPartitionFunction: public wallaroo::PartitionFunctionU64
{
public:
  ArizonaPartitionFunction() {}
  virtual ~ArizonaPartitionFunction() {}
  virtual uint64_t partition(wallaroo::Data *data_);
  virtual void serialize(char* bytes_, size_t nsz_) { Writer writer((unsigned char *)bytes_); writer.u16_be(SerializationType::PartitionFunction); }
  virtual size_t serialize_get_size () { return 2; }
};

#endif
