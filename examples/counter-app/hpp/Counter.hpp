#ifndef __COUNTER_HPP__
#define __COUNTER_HPP__

#include "WallarooCppApi/Data.hpp"
#include "WallarooCppApi/Key.hpp"
#include "WallarooCppApi/PartitionFunction.hpp"
#include "WallarooCppApi/State.hpp"
#include "WallarooCppApi/StateChange.hpp"
#include "WallarooCppApi/StateBuilder.hpp"
#include "WallarooCppApi/Computation.hpp"
#include "WallarooCppApi/ComputationBuilder.hpp"
#include "WallarooCppApi/SourceDecoder.hpp"
#include "WallarooCppApi/SinkEncoder.hpp"
#include <vector>
#include <iostream>

class Numbers: public wallaroo::Data
{
private:
  std::vector<uint32_t> numbers;
public:
  Numbers();
  Numbers(Numbers& n);
  void decode(char* bytes);
  virtual ~Numbers() { }
  std::vector<uint32_t> get_numbers() { return numbers; }
  uint32_t sum();

  virtual void deserialize (char* bytes);
  virtual void serialize (char* bytes);
  virtual size_t serialize_get_size ();
  size_t encode_get_size();
  void encode(char *bytes);
};

class Total: public wallaroo::Data
{
private:
  uint64_t _total;
public:
  Total(Total& t);
  Total(uint64_t total);
  virtual void deserialize (char* bytes);
  virtual void serialize (char* bytes);
  virtual size_t serialize_get_size () { return 10; }
  virtual size_t encode_get_size() { return 8; }
  virtual void encode(char *bytes);
  virtual ~Total() {};
};

class CounterSourceDecoder: public wallaroo::SourceDecoder
{
public:
  virtual size_t header_length();
  virtual size_t payload_length(char *bytes);
  virtual Numbers *decode(char *bytes);
};

class CounterSinkEncoder: public wallaroo::SinkEncoder
{
public:
  virtual size_t get_size(wallaroo::Data *data);
  virtual void encode(wallaroo::Data *data, char *bytes);

  virtual void deserialize (char* bytes) {};
  virtual void serialize (char* bytes) { bytes[0] = 0; bytes[1] = 4; }
  virtual size_t serialize_get_size () { return 2; }
};

class CounterState: public wallaroo::State
{
private:
  uint64_t _counter;
public:
  CounterState();
  void add(uint64_t value);
  uint64_t get_counter();
};

class CounterStateBuilder: public wallaroo::StateBuilder
{
public:
  const char *name();
  wallaroo::State *build();
};

class CounterAdd: public wallaroo::StateChange
{
private:
  uint64_t _id;
  uint64_t _value;
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
  void set_value(uint64_t value_);
};

class CounterAddBuilder: public wallaroo::StateChangeBuilder
{
public:
  virtual wallaroo::StateChange *build(uint64_t idx_);
  virtual void deserialize (char* bytes);
  virtual void serialize (char* bytes);
  virtual size_t serialize_get_size ();
};

class SimpleComputationBuilder: public wallaroo::ComputationBuilder
{
public:
  virtual wallaroo::Computation *build();
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
  virtual void serialize (char* bytes) { bytes[0] = 0; bytes[1] = 2; }
  virtual size_t serialize_get_size () { return 2; }
};

#endif
