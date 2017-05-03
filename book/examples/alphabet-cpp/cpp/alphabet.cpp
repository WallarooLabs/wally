#include "WallarooCppApi/Application.hpp"
#include "WallarooCppApi/ApiHooks.hpp"

#include "alphabet.hpp"

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

extern "C" {
  extern wallaroo::Serializable* w_user_serializable_deserialize (char* bytes_)
  {
    uint8_t serialization_type = bytes_[0];
    switch (serialization_type)
    {
    case SerializationTypes::Votes:
    {
      char letter = bytes_[1];
      char count = be32toh(*((uint32_t *)(bytes_ + 2)));
      return new Votes(letter, count);
    }
    case SerializationTypes::LetterTotal:
    {
      char letter = bytes_[1];
      char count = be32toh(*((uint32_t *)(bytes_ + 2)));
      return new LetterTotal(letter, count);
    }
    case SerializationTypes::AddVotes:
      return new AddVotes();
    case SerializationTypes::AddVotesStateChangeBuilder:
      return new AddVotesStateChangeBuilder();
    case SerializationTypes::LetterStateBuilder:
      return new LetterStateBuilder();
    case SerializationTypes::LetterTotalEncoder:
      return new LetterTotalEncoder();
    }

    return NULL;
  }

  extern bool w_main(int argc, char **argv, Application *application_builder_)
  {
    application_builder_->create_application("Alphabet Popularity Contest")
      ->new_pipeline("Alphabet Votes", new VotesDecoder())
      ->to_state_partition_u64(
        new AddVotes(), // state_computation
        new LetterStateBuilder(), // state_builder
        "letter-state",
        new LetterPartition(),
        true // multi_worker
        )
      ->to_sink(new LetterTotalEncoder());

    return true;
  }
}

Votes::Votes(char l_, uint32_t c_): m_letter(l_), m_count(c_)
{
}

void Votes::serialize (char* bytes_)
{
  bytes_[0] = SerializationTypes::Votes;
  bytes_[1] = m_letter;
  *(uint32_t *)(bytes_ + 2) = htobe32(m_count);
}

size_t Votes::serialize_get_size ()
{
  return 6;
}

LetterTotal::LetterTotal(char l_, uint32_t c_): m_letter(l_), m_count(c_)
{
}

void LetterTotal::serialize (char* bytes_)
{
  bytes_[0] = SerializationTypes::LetterTotal;
  bytes_[1] = m_letter;
  *(uint32_t *)(bytes_ + 2) = htobe32(m_count);
}

size_t LetterTotal::serialize_get_size ()
{
  return 6;
}

uint64_t LetterPartitionFunction::partition(wallaroo::Data *data_)
{
  Votes *votes = static_cast<Votes *>(data_);
  return votes->m_letter;
}

PartitionFunctionU64 *LetterPartition::get_partition_function()
{
  return new LetterPartitionFunction();
}

size_t LetterPartition::get_number_of_keys()
{
  return 26;
}

uint64_t LetterPartition::get_key(size_t idx_)
{
  return 'a' + idx_;
}

LetterState::LetterState(): m_letter(' '), m_count(0)
{
}

const char *LetterStateBuilder::name()
{
  return "LetterStateBuilder";
}

State *LetterStateBuilder::build()
{
  return new LetterState();
}

void LetterStateBuilder::serialize (char* bytes_)
{
  bytes_[0] = SerializationTypes::LetterStateBuilder;
}

size_t LetterStateBuilder::serialize_get_size ()
{
  return 1;
}

const char *AddVotesStateChange::s_name = "add votes state change";

AddVotesStateChange::AddVotesStateChange(uint64_t id): m_id(id), m_votes(' ', 0)
{
}

const char *AddVotesStateChange::name()
{
  return s_name;
}

void AddVotesStateChange::apply(State *state_)
{
  LetterState *letter_state = static_cast<LetterState *>(state_);

  letter_state->m_letter = m_votes.m_letter;
  letter_state->m_count += m_votes.m_count;
}

void AddVotesStateChange::to_log_entry(char *bytes_)
{
  bytes_[0] = m_votes.m_letter;
  *(uint32_t *)(bytes_ + 1) = htobe32(m_votes.m_count);
}

size_t AddVotesStateChange::get_log_entry_size()
{
  return 5;
}

size_t AddVotesStateChange::get_log_entry_size_header_size()
{
  return 0;
}

size_t AddVotesStateChange::read_log_entry_size_header(char *bytes_)
{
  return 0;
}

bool AddVotesStateChange::read_log_entry(char *bytes_)
{
  m_votes.m_letter = bytes_[0];
  m_votes.m_count = be32toh(*((uint32_t *)(bytes_ + 1)));
  return true;
}

void AddVotesStateChange::update(Votes votes_)
{
  m_votes = votes_;
}

uint64_t AddVotesStateChange::id()
{
  return m_id;
}

StateChange *AddVotesStateChangeBuilder::build(uint64_t id_)
{
  return new AddVotesStateChange(id_);
}

void AddVotesStateChangeBuilder::serialize (char* bytes_)
{
  bytes_[0] = SerializationTypes::AddVotesStateChangeBuilder;
}

size_t AddVotesStateChangeBuilder::serialize_get_size ()
{
  return 1;
}

const char *AddVotes::name()
{
  return "add votes";
}

void *AddVotes::compute(
  Data *input_,
  StateChangeRepository *state_change_repository_,
  void* state_change_repository_helper_, State *state_, void *none)
{
  Votes *votes = static_cast<Votes *>(input_);

  LetterState *letter_state = static_cast<LetterState *>(state_);

  void *state_change_handle = w_state_change_repository_lookup_by_name(
    state_change_repository_helper_, state_change_repository_, AddVotesStateChange::s_name);

  AddVotesStateChange *add_votes_state_change = static_cast<AddVotesStateChange*>(
    w_state_change_get_state_change_object(state_change_repository_helper_, state_change_handle));

  add_votes_state_change->update(*votes);

  LetterTotal *letter_total = new LetterTotal(letter_state->m_letter, letter_state->m_count);

  return w_stateful_computation_get_return(state_change_repository_helper_, letter_total, state_change_handle);
}

size_t AddVotes::get_number_of_state_change_builders()
{
  return 1;
}

StateChangeBuilder *AddVotes::get_state_change_builder(size_t idx_)
{
  return new AddVotesStateChangeBuilder();
}

void AddVotes::serialize (char* bytes_)
{
  bytes_[0] = SerializationTypes::AddVotes;
}

size_t AddVotes::serialize_get_size ()
{
  return 1;
}

size_t VotesDecoder::header_length()
{
  return 4;
}

size_t VotesDecoder::payload_length(char *bytes_)
{
  return be32toh(*((uint32_t *)(bytes_)));
}

Data *VotesDecoder::decode(char *bytes_, size_t sz_)
{
  char letter = bytes_[0];
  uint32_t count = be32toh(*((uint32_t *)(bytes_ + 1)));
  return new Votes(letter, count);
}

size_t LetterTotalEncoder::get_size(Data *data_)
{
  return 9;
}

void LetterTotalEncoder::encode(Data *data_, char *bytes_)
{
  LetterTotal *letter_total = static_cast<LetterTotal *>(data_);
  *(uint32_t *)(bytes_) = htobe32(5);
  bytes_[4] = letter_total->m_letter;
  *(uint32_t *)(bytes_ + 5) = htobe32(letter_total->m_count);
}

void LetterTotalEncoder::serialize (char* bytes_)
{
  bytes_[0] = SerializationTypes::LetterTotalEncoder;
}

size_t LetterTotalEncoder::serialize_get_size ()
{
  return 1;
}
