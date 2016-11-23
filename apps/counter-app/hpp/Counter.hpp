#ifndef __COUNTER_HPP__
#define __COUNTER_HPP__

#include "WallarooCppApi/Data.hpp"
#include "WallarooCppApi/Key.hpp"
#include "WallarooCppApi/PartitionFunction.hpp"
#include "WallarooCppApi/State.hpp"
#include "WallarooCppApi/StateChange.hpp"
#include "WallarooCppApi/Computation.hpp"
#include "WallarooCppApi/SourceDecoder.hpp"
#include "WallarooCppApi/SinkEncoder.hpp"
#include <vector>
#include <iostream>

class Numbers: public wallaroo::EncodableData
{
private:
  std::vector<int> numbers;
public:
  Numbers();
  Numbers(Numbers& n);
  void decode(char* bytes);
  virtual ~Numbers() {}
  std::vector<int> get_numbers() { return numbers; }
  int sum();

  virtual void deserialize (char* bytes);
  virtual void serialize (char* bytes, size_t nsz_);
  virtual size_t serialize_get_size ();
  virtual size_t encode_get_size();
  virtual void encode(char *bytes);
};

class Total: public wallaroo::EncodableData
{
private:
  int _total;
public:
  Total(Total& t);
  Total(int total);
  virtual void deserialize (char* bytes);
  virtual void serialize (char* bytes, size_t nsz_);
  virtual size_t serialize_get_size () { return 6; }
  virtual size_t encode_get_size() { return 4; }
  virtual void encode(char *bytes);
  virtual ~Total() {};
};

class CounterSourceDecoder: public wallaroo::SourceDecoder
{
public:
  virtual size_t header_length();
  virtual size_t payload_length(char *bytes);
  virtual Numbers *decode(char *bytes, size_t sz_);
};

class CounterSinkEncoder: public wallaroo::SinkEncoder
{
public:
  virtual size_t get_size(wallaroo::EncodableData *data);
  virtual void encode(wallaroo::EncodableData *data, char *bytes);

  virtual void deserialize (char* bytes) {};
  virtual void serialize (char* bytes, size_t nsz_) { bytes[0] = 0; bytes[1] = 4; }
  virtual size_t serialize_get_size () { return 2; }
};

class CounterState: public wallaroo::State
{
private:
  int _counter;
public:
  CounterState();
  void add(int value);
  int get_counter();
};

class CounterAdd: public wallaroo::StateChange
{
private:
  uint64_t _id;
  int _value;
public:
  CounterAdd(uint64_t id);
  virtual const char *name();
  virtual uint64_t id();
  virtual void apply(wallaroo::State *state_);
  virtual size_t get_log_entry_size();
  virtual void to_log_entry(char *bytes_);
  virtual size_t get_log_entry_size_header_size();
  virtual size_t read_log_entry_size_header(char *bytes_) { return 0; }
  virtual bool read_log_entry(char *bytes_);
  void set_value(int value_);
};

class CounterAddBuilder: public wallaroo::StateChangeBuilder
{
public:
  virtual wallaroo::StateChange *build(uint64_t idx_);
  virtual void deserialize (char* bytes);
  virtual void serialize (char* bytes, size_t nsz_);
  virtual size_t serialize_get_size ();
};

class SimpleComputation: public wallaroo::Computation
{
public:
  virtual const char *name();
  virtual wallaroo::Data *compute(wallaroo::Data *input_);
};

class CounterComputation: public wallaroo::StateComputation
{
public:
  virtual const char *name();
  virtual void *compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void* state_change_Respository_helper_, wallaroo::State *state_, void *none);
  virtual size_t get_number_of_state_change_builders();
  virtual wallaroo::StateChangeBuilder *get_state_change_builder(size_t idx_);
  virtual void deserialize (char* bytes) {};
  virtual void serialize (char* bytes, size_t nsz_) { bytes[0] = 0; bytes[1] = 2; }
  virtual size_t serialize_get_size () { return 2; }
};

class DummyComputation: public wallaroo::StateComputation
{
public:
  virtual const char *name();
  virtual void *compute(wallaroo::Data *input_, wallaroo::StateChangeRepository *state_change_repository_, void* state_change_Respository_helper_, wallaroo::State *state_, void *none);
  virtual size_t get_number_of_state_change_builders();
  virtual wallaroo::StateChangeBuilder *get_state_change_builder(size_t idx_);
  virtual void deserialize (char* bytes) {};
  virtual void serialize (char* bytes, size_t nsz_) { bytes[0] = 0; bytes[1] = 1; }
  virtual size_t serialize_get_size () { return 2; }
};

class CounterPartitionKey: public wallaroo::Key
{
private:
  size_t _value;
public:
  CounterPartitionKey(size_t value_);
  virtual ~CounterPartitionKey() {}
  virtual uint64_t hash();
  virtual bool eq(wallaroo::Key *other_);
  size_t get_value();
  virtual void deserialize (char* bytes_);
  virtual void serialize (char* bytes_, size_t nsz_);
  virtual size_t serialize_get_size () { return 6; }
};

class CounterPartitionFunction: public wallaroo::PartitionFunction
{
public:
  CounterPartitionFunction() {}
  virtual ~CounterPartitionFunction() {}
  virtual wallaroo::Key *partition(wallaroo::Data *data_);
};

#endif
