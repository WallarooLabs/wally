#ifndef __ALPHABET_HPP__
#define __ALPHABET_HPP__

#include "WallarooCppApi/Data.hpp"
#include "WallarooCppApi/Computation.hpp"
#include "WallarooCppApi/StateBuilder.hpp"
#include "WallarooCppApi/State.hpp"
#include "WallarooCppApi/StateChangeBuilder.hpp"
#include "WallarooCppApi/StateChange.hpp"
#include "WallarooCppApi/Partition.hpp"
#include "WallarooCppApi/SourceDecoder.hpp"
#include "WallarooCppApi/SinkEncoder.hpp"

using namespace wallaroo;

namespace SerializationTypes
{
  // data
  const uint8_t Votes = 1;
  const uint8_t LetterTotal = 2;

  // state computations
  const uint8_t AddVotes = 3;

  // state change builders
  const uint8_t AddVotesStateChangeBuilder = 4;

  // state builders
  const uint8_t LetterStateBuilder = 5;

  // encoder
  const uint8_t LetterTotalEncoder = 6;
};

class Votes: public Data
{
public:
  char m_letter;
  uint32_t m_count;
  Votes(char l_, uint32_t c_);

  virtual void serialize (char* bytes_);
  virtual size_t serialize_get_size ();
};

class LetterTotal: public Data
{
public:
  char m_letter;
  uint32_t m_count;
  LetterTotal(char l_, uint32_t c_);

  virtual void serialize (char* bytes_);
  virtual size_t serialize_get_size ();
};

class LetterPartitionFunction: public PartitionFunctionU64
{
public:
  virtual uint64_t partition(Data *data_);
};

class LetterPartition: public PartitionU64
{
  virtual PartitionFunctionU64 *get_partition_function();
  virtual size_t get_number_of_keys();
  virtual uint64_t get_key(size_t idx_);
};

class LetterState: public State
{
public:
  LetterState();
  char m_letter;
  uint32_t m_count;
};

class LetterStateBuilder: public StateBuilder
{
public:
  const char *name();
  State *build();

  virtual void serialize (char* bytes_);
  virtual size_t serialize_get_size ();
};

class AddVotesStateChange: public StateChange
{
private:
  uint64_t m_id;
  Votes m_votes;
public:
  static const char *s_name;

  AddVotesStateChange(uint64_t id_);
  virtual const char *name();
  virtual void apply(State *state_);
  virtual void to_log_entry(char *bytes_);
  virtual size_t get_log_entry_size();
  virtual size_t get_log_entry_size_header_size();
  virtual size_t read_log_entry_size_header(char *bytes_);
  virtual bool read_log_entry(char *bytes_);
  virtual uint64_t id();

  void update(Votes votes);
};

class AddVotesStateChangeBuilder: public StateChangeBuilder
{
public:
  virtual StateChange *build(uint64_t id_);

  virtual void serialize (char* bytes_);
  virtual size_t serialize_get_size ();
};

class AddVotes: public StateComputation
{
  virtual const char *name();
  virtual void *compute(
    Data *input_,
    StateChangeRepository *state_change_repository_,
    void* state_change_repository_helper_, State *state_, void *none);
  virtual size_t get_number_of_state_change_builders();
  virtual StateChangeBuilder *get_state_change_builder(size_t idx_);

  virtual void serialize (char* bytes_);
  virtual size_t serialize_get_size ();
};

class VotesDecoder: public SourceDecoder
{
public:
  virtual size_t header_length();
  virtual size_t payload_length(char *bytes_);
  virtual Data *decode(char *bytes_, size_t sz_);
};

class LetterTotalEncoder: public SinkEncoder
{
public:
  virtual size_t get_size(Data *data_);
  virtual void encode(Data *data_, char *bytes_);

  virtual void serialize (char* bytes_);
  virtual size_t serialize_get_size ();
};

#endif // __ALPHABET_HPP__
