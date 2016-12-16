#ifndef __ARIZONA_SOURCE_HPP__
#define __ARIZONA_SOURCE_HPP__

#include "WallarooCppApi/Serializable.hpp"
#include "WallarooCppApi/SourceDecoder.hpp"
#include "WallarooCppApi/SinkEncoder.hpp"
#include "WallarooCppApi/Computation.hpp"
#include "WallarooCppApi/State.hpp"
#include "WallarooCppApi/Data.hpp"
#include "WallarooCppApi/Key.hpp"
#include "WallarooCppApi/PartitionFunction.hpp"
#include "ArizonaState.hpp"
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

class ClientMessage: public wallaroo::Data
{
public:
  virtual ~ClientMessage(){};
public:
  virtual string *get_client() = 0;
  virtual uint32_t get_client_id() = 0;
  virtual int get_message_type() = 0;
  virtual uint64_t get_message_id() = 0;
  virtual string str() = 0;
  virtual void from_bytes(char *bytes_) = 0;
};

class ConfigMessage: public ClientMessage
{
private:
  uint64_t _message_id;
  uint32_t _client_id;
public:
  ConfigMessage(uint64_t message_id, uint32_t client_id);
  virtual ~ConfigMessage();
  uint64_t get_message_id() { return _message_id; }
  virtual void from_bytes(char *bytes_) { }
  virtual int get_message_type() { return -1; }
  virtual string *get_client() { return new string(""); }
  virtual uint32_t get_client_id() { return _client_id; }
  virtual string str();
};



class OrderMessage: /*public wallaroo::Data,*/ public ClientMessage
{
private:
  uint64_t _message_id;
  uint32_t _client_id;
  string *_client;
  string *_account;
  string *_isin;
  string *_order_id;
  uint16_t _order_type;
  uint16_t _side;
  uint32_t _quantity;
  double _price;
public:
  OrderMessage(uint64_t message_id, uint32_t client_id);
  virtual ~OrderMessage();
  uint32_t get_client_id() { return _client_id; }
  uint64_t get_message_id() { return _message_id; }
  string *get_client() { return _client; }
  string *get_account() { return _account; }
  string *get_isin() { return _isin; }
  string *get_order_id() { return _order_id; }
  uint16_t get_side() { return _side; }
  uint32_t get_quantity() { return _quantity; }
  double get_price() { return _price; }
  virtual void from_bytes(char *bytes_);
  virtual void serialize(char* bytes_, size_t nsz_);
  virtual size_t serialize_get_size();
  virtual int get_message_type() { return 1; }
  virtual string str();
};

class CancelMessage: /*public wallaroo::Data,*/ public ClientMessage
{
private:
  uint64_t _message_id;
  uint32_t _client_id;
  string *_client;
  string *_account;
  string *_order_id;
  string *_cancel_id;
public:
  CancelMessage(uint64_t message_id, uint32_t client_id);
  virtual ~CancelMessage();
  virtual string *get_client() { return _client; }
  string *get_account() { return _account; }
  string *get_order_id() { return _order_id; }
  virtual uint32_t get_client_id() { return _client_id; }
  virtual uint64_t get_message_id() { return _message_id; }
  virtual void from_bytes(char *bytes_);
  virtual void serialize(char* bytes_, size_t nsz_);
  virtual size_t serialize_get_size();
  virtual int get_message_type() { return 2; }
  virtual string str();
};

class ExecuteMessage: /* public wallaroo::Data, */public ClientMessage
{
private:
  uint64_t _message_id;
  uint32_t _client_id;
  string *_client;
  string *_account;
  string *_order_id;
  string *_execution_id;
  uint32_t _quantity;
  double _price;
public:
  ExecuteMessage(uint64_t message_id, uint32_t client_id);
  virtual ~ExecuteMessage();
  virtual string *get_client() { return _client; }
  virtual uint32_t get_client_id() { return _client_id; }
  virtual uint64_t get_message_id() { return _message_id; }
  virtual void from_bytes(char *bytes_);
  virtual void serialize(char* bytes_, size_t nsz_);
  virtual size_t serialize_get_size();
  virtual int get_message_type() { return 2; }
  virtual string str();
};

class AdminMessage: /*public wallaroo::Data, */public ClientMessage
{
private:
  uint64_t _message_id;
  uint32_t _client_id;
  uint16_t _request_type;
  string *_client;
  string *_account;
public:
  AdminMessage(uint64_t message_id_, uint32_t client_id);
  virtual ~AdminMessage();
  virtual string *get_client() { return _client; }
  virtual uint32_t get_client_id() { return _client_id; }
  virtual uint64_t get_message_id() { return _message_id; }
  virtual void from_bytes(char *bytes);
  virtual void serialize(char* bytes_, size_t nsz_);
  virtual size_t serialize_get_size();
  virtual int get_message_type() { return 4; }
  virtual string str();
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
private:
  Clients _clients;
public:
  ArizonaState(): _clients() {};
  class Proceeds proceeds_with_order(string& client_id_, string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_);
  void add_order(string& client_id_, string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_);

  class Proceeds proceeds_with_cancel(string& client_id_, string& account_id_, string& order_id_);
  void cancel_order(string& client_id_, string& account_id_, string& order_id_);
};

class AddOrderStateChange: public wallaroo::StateChange
{
private:
  string _client_id;
  string _account_id;
  string _isin_id;
  string _order_id;
  Side _side;
  uint32_t _quantity;
  double _price;
public:
  AddOrderStateChange(uint64_t id_);
  virtual const char* name() { return "add order state change"; };
  virtual void apply(wallaroo::State *state_);
  virtual void to_log_entry(char *bytes_) {}
  virtual size_t get_log_entry_size() { return 0; }
  virtual size_t get_log_entry_size_header_size() { return 0; }
  virtual size_t read_log_entry_size_header(char *bytes_) { return 0; }
  virtual bool read_log_entry(char *bytes_) { return true; }
  void update(string& client_id_, string& account_id_, string& isin_id_, string& order_id_, uint16_t side_, uint32_t quantity_, double price_);
};

class AddOrderStateChangeBuilder: public wallaroo::StateChangeBuilder
{
  virtual wallaroo::StateChange *build(uint64_t id_) { return new AddOrderStateChange(id_); }
};

class CancelOrderStateChange: public wallaroo::StateChange
{
private:
  string _client_id;
  string _account_id;
  string _order_id;
public:
  CancelOrderStateChange(uint64_t id_);
  virtual const char* name() { return "cancel order state change"; };
  virtual void apply(wallaroo::State *state_);
  virtual void to_log_entry(char *bytes_) {}
  virtual size_t get_log_entry_size() { return 0; }
  virtual size_t get_log_entry_size_header_size() { return 0; }
  virtual size_t read_log_entry_size_header(char *bytes_) { return 0; }
  virtual bool read_log_entry(char *bytes_) { return true; }
  void update(string& client_id_, string& account_id_, string& order_id_);
};

class CancelOrderStateChangeBuilder: public wallaroo::StateChangeBuilder
{
  virtual wallaroo::StateChange *build(uint64_t id_) { return new CancelOrderStateChange(id_); }
};

class ArizonaDefaultState: public wallaroo::State
{
private:
  Clients _clients;
public:
  ArizonaDefaultState(): _clients() {};
  class Proceeds proceeds_with_order(string& client_id_, string& account_id_, string& isin_id_, string& order_id_, Side side_, uint32_t quantity_, double price_);
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
  virtual size_t get_number_of_state_change_builders() { return 2;}
  virtual wallaroo::StateChangeBuilder *get_state_change_builder(size_t idx_);
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

class PassThroughComputation: public wallaroo::Computation
{
  public:
    virtual const char *name();
    virtual wallaroo::Data *compute(wallaroo::Data *input_);
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
