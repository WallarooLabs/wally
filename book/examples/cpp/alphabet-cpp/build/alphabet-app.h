#ifndef pony_alphabet-app_h
#define pony_alphabet-app_h

/* This is an auto-generated header file. Do not edit. */

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _MSC_VER
typedef struct __int128_t { uint64_t low; int64_t high; } __int128_t;
typedef struct __uint128_t { uint64_t low; uint64_t high; } __uint128_t;
#endif

typedef struct u3_t2_String_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A buffer for building messages.

`Writer` provides an way to create byte sequences using common
data encodings. The `Writer` manages the underlying arrays and
sizes. It is useful for encoding data to send over a network or
store in a file. Once a message has been built you can call `done()`
to get the message's `ByteSeq`s, and you can then reuse the
`Writer` for creating a new message.

For example, suppose we have a TCP-based network data protocol where
messages consist of the following:

* `message_length` - the number of bytes in the message as a
  big-endian 32-bit integer
* `list_size` - the number of items in the following list of items
  as a big-endian 32-bit integer
* zero or more items of the following data:
  * a big-endian 64-bit floating point number
  * a string that starts with a big-endian 32-bit integer that
    specifies the length of the string, followed by a number of
    bytes that represent the string

A message would be something like this:

```
[message_length][list_size][float1][string1][float2][string2]...
```

The following program uses a write buffer to encode an array of
tuples as a message of this type:

```
use "net"

actor Main
  new create(env: Env) =>
    let wb = Writer
    let messages = [[(F32(3597.82), "Anderson"), (F32(-7979.3), "Graham")],
                    [(F32(3.14159), "Hopper"), (F32(-83.83), "Jones")]]
    for items in messages.values() do
      wb.i32_be((items.size() / 2).i32())
      for (f, s) in items.values() do
        wb.f32_be(f)
        wb.i32_be(s.size().i32())
        wb.write(s.array())
      end
      let wb_msg = Writer
      wb_msg.i32_be(wb.size().i32())
      wb_msg.writev(wb.done())
      env.out.writev(wb_msg.done())
    end
```
*/
typedef struct buffered_Writer buffered_Writer;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections__MapEmpty_val_collections__MapDeleted_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_val collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_ref ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_ref;

typedef struct ArrayValues_U64_val_Array_U64_val_val ArrayValues_U64_val_Array_U64_val_val;

typedef struct Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U64_val_routing__Route_ref_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U64_val_routing__Route_ref_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_KeyedStateSubpartition_pony_CPPData_val_U64_val topology_KeyedStateSubpartition_pony_CPPData_val_U64_val;

typedef struct topology_$36$115 topology_$36$115;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val collections_HashMap_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val;

typedef struct u2_options__Option_ref_options_ParseError_ref u2_options__Option_ref_options_ParseError_ref;

/*
This is a capability that allows the holder to serialise objects. It does not
allow the holder to examine serialised data or to deserialise objects.
*/
typedef struct serialise_SerialiseAuth serialise_SerialiseAuth;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_Any_tag_Any_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_Any_tag_Any_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct t2_routing_Consumer_tag_routing_Route_box t2_routing_Consumer_tag_routing_Route_box;

typedef struct u3_t2_String_val_net_TCPConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_net_TCPConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u2_routing__Route_ref_None_val u2_routing__Route_ref_None_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val;

typedef struct routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val;

typedef struct u2_routing_Route_ref_None_val u2_routing_Route_ref_None_val;

typedef struct $0$1_String_val $0$1_String_val;

typedef struct data_channel_DataChannelListener data_channel_DataChannelListener;

typedef struct ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_ref ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_ref;

/*
This message is sent to notify another worker that a new stateful step has
been created on this worker and that partition routers should be updated.
*/
typedef struct messages_KeyedAnnounceNewStatefulStepMsg_U8_val messages_KeyedAnnounceNewStatefulStepMsg_U8_val;

typedef struct net_NetAuth net_NetAuth;

typedef struct topology_$36$135_pony_CPPKey_val topology_$36$135_pony_CPPKey_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u2_topology_PartitionBuilder_val_None_val u2_topology_PartitionBuilder_val_None_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val;

typedef struct u2_pony_CPPData_val_None_val u2_pony_CPPData_val_None_val;

typedef struct t2_U128_val_topology_SourceData_val t2_U128_val_topology_SourceData_val;

typedef struct t2_Array_U8_val_val_USize_val t2_Array_U8_val_val_USize_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u2_String_val_Array_U8_val_val Array_u2_String_val_Array_U8_val_val;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_val collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_val;

typedef struct u2_collections_ListNode_time_Timer_ref_val_None_val u2_collections_ListNode_time_Timer_ref_val_None_val;

typedef struct boundary_$10$22 boundary_$10$22;

typedef struct ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_ref ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_ref;

typedef struct topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_U8_val topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_U8_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_topology_StepBuilder_val Array_topology_StepBuilder_val;

typedef struct u3_Less_val_Equal_val_Greater_val u3_Less_val_Equal_val_Greater_val;

typedef struct options_AmbiguousMatch options_AmbiguousMatch;

typedef struct recovery__NotRecovering recovery__NotRecovering;

typedef struct t2_String_val_boundary_OutgoingBoundary_tag t2_String_val_boundary_OutgoingBoundary_tag;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_metrics__MetricsReporter_ref_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_metrics__MetricsReporter_ref_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_$36$132 topology_$36$132;

typedef struct topology_$36$104 topology_$36$104;

typedef struct u3_t2_net_TCPListener_tag_net_TCPListener_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_net_TCPListener_tag_net_TCPListener_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct $0$13_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref $0$13_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref;

typedef struct routing_$35$96_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val routing_$35$96_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val;

typedef struct ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_ref ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_ref;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val;

typedef struct $0$1_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref $0$1_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref;

typedef struct t2_String_iso_String_iso t2_String_iso_String_iso;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_ref collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_ref;

typedef struct ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_val ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_val;

typedef struct u2_http_ResponseHandler_val_None_val u2_http_ResponseHandler_val_None_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_initialization_LocalTopology_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_initialization_LocalTopology_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u3_t2_String_val_boundary_OutgoingBoundary_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_boundary_OutgoingBoundary_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u2_Any_tag_None_val u2_Any_tag_None_val;

typedef struct topology_$36$101_pony_CPPData_val topology_$36$101_pony_CPPData_val;

/*
Accept an iterable collection of String or Array[U8] val.
*/
typedef struct ByteSeqIter ByteSeqIter;

typedef struct messages1__Done messages1__Done;

typedef struct u2_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_None_val u2_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_None_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_topology_PreStateData_val Array_topology_PreStateData_val;

typedef struct ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_box ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_box;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_val collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_val;

typedef struct t2_topology_Step_tag_topology_Step_tag t2_topology_Step_tag_topology_Step_tag;

typedef struct t2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_collections_ListNode_t2_Array_U8_val_val_USize_val_ref t2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_collections_ListNode_t2_Array_U8_val_val_USize_val_ref;

typedef struct u3_t2_String_val_topology_PartitionAddresses_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_topology_PartitionAddresses_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_EgressBuilder topology_EgressBuilder;

typedef struct ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_ref ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_ref;

typedef struct t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box;

typedef struct files__PathSep files__PathSep;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_U64_val Array_U64_val;

typedef struct collections_HashIs_U128_val collections_HashIs_U128_val;

typedef struct topology_RunnableStep topology_RunnableStep;

typedef struct t2_time_Timer_tag_time_Timer_ref t2_time_Timer_tag_time_Timer_ref;

/*
# Step

## Future work
* Switch to requesting credits via promise
*/
typedef struct topology_Step topology_Step;

typedef struct u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_ref collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_ref;

typedef struct u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val;

typedef struct ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_val ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_val;

typedef struct t2_U32_val_U8_val t2_U32_val_U8_val;

typedef struct ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_box ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_box;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_t3_U8_val_U128_val_topology_Step_tag Array_t3_U8_val_U128_val_topology_Step_tag;

typedef struct t2_String_val_metrics__MetricsReporter_box t2_String_val_metrics__MetricsReporter_box;

typedef struct topology_$36$97 topology_$36$97;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_val collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_box collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_box;

typedef struct recovery_Resilient recovery_Resilient;

typedef struct topology_$36$125_pony_CPPKey_val topology_$36$125_pony_CPPKey_val;

/*
  A String is an ordered collection of characters.

  Strings don't specify an encoding.

  Example usage of some common String methods:

```pony
actor Main
  new create(env: Env) =>
    try
      // construct a new string
      let str = "Hello"

      // make an uppercased version
      let str_upper = str.upper()
      // make a reversed version
      let str_reversed = str.reverse()

      // add " world" to the end of our original string
      let str_new = str.add(" world")

      // count occurrences of letter "l"
      let count = str_new.count("l")

      // find first occurrence of letter "w"
      let first_w = str_new.find("w")
      // find first occurrence of letter "d"
      let first_d = str_new.find("d")

      // get substring capturing "world"
      let substr = str_new.substring(first_w, first_d+1)
      // clone substring
      let substr_clone = substr.clone()

      // print our substr
      env.out.print(consume substr)
  end
```
  */
typedef struct String String;

typedef struct u2_data_channel_DataChannelListener_tag_None_val u2_data_channel_DataChannelListener_tag_None_val;

typedef struct initialization_InitFileNotify initialization_InitFileNotify;

typedef struct u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u3_t2_U128_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U128_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag;

typedef struct u2_time__ClockRealtime_val_time__ClockMonotonic_val u2_time__ClockRealtime_val_time__ClockMonotonic_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_val collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_USize_val_wallaroo_InitFile_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_USize_val_wallaroo_InitFile_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct routing__Route routing__Route;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
This is a capability token that allows the holder to deserialise objects. It
does not allow the holder to serialise objects or examine serialised.
*/
typedef struct serialise_DeserialiseAuth serialise_DeserialiseAuth;

typedef struct metrics_$29$10 metrics_$29$10;

typedef struct pony_CPPStateChange pony_CPPStateChange;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_Array_u2_String_val_Array_U8_val_val_val Array_Array_u2_String_val_Array_U8_val_val_val;

typedef struct ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_box ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_box;

typedef struct u2_pony_CPPStateChange_ref_None_val u2_pony_CPPStateChange_ref_None_val;

/*
A node in a list.
*/
typedef struct collections_ListNode_time_Timer_ref collections_ListNode_time_Timer_ref;

typedef struct t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn;

typedef struct t2_String_val_U64_val t2_String_val_U64_val;

/*
A doubly linked list.
*/
typedef struct collections_List_t2_u2_String_val_Array_U8_val_val_USize_val collections_List_t2_u2_String_val_Array_U8_val_val_USize_val;

typedef struct t2_String_val_Bool_val t2_String_val_Bool_val;

typedef struct collections_HashIs_String_val collections_HashIs_String_val;

typedef struct u2_ssl_SSLContext_val_None_val u2_ssl_SSLContext_val_None_val;

/*
Convenience operations on file descriptors.
*/
typedef struct files__FileDes files__FileDes;

/*
A set, built on top of a HashMap. This is implemented as map of an alias of
a type to itself
*/
typedef struct collections_HashSet_routing_RouteLogic_ref_collections_HashIs_routing_RouteLogic_ref_val collections_HashSet_routing_RouteLogic_ref_collections_HashIs_routing_RouteLogic_ref_val;

typedef struct u3_t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct http_URLPartPassword http_URLPartPassword;

/*
Asynchronous access to stdout and stderr. The constructors are private to
ensure that access is provided only via an environment.
*/
typedef struct StdStream StdStream;

typedef struct u2_collections_List_time_Timer_ref_ref_None_val u2_collections_List_time_Timer_ref_ref_None_val;

typedef struct data_channel_DataChannel data_channel_DataChannel;

typedef struct recovery_EventLog recovery_EventLog;

typedef struct topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_val collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_val;

typedef struct messages_MuteRequestMsg messages_MuteRequestMsg;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct messages_AckMigrationBatchCompleteMsg messages_AckMigrationBatchCompleteMsg;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val;

/*
Produces [min, max).
*/
typedef struct collections_Range_USize_val collections_Range_USize_val;

/*
This message is sent to notify another worker that a new stateful step has
been created on this worker and that partition routers should be updated.
*/
typedef struct messages_KeyedAnnounceNewStatefulStepMsg_U64_val messages_KeyedAnnounceNewStatefulStepMsg_U64_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_val collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U64_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U64_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
Phases (if on a recovering worker):
  1) _NotRecoveryReplaying: Wait for start_recovery_replay() to be called
  2) _WaitingForBoundaryCounts: Wait for every running worker to inform this
     worker of how many boundaries they have incoming to us. We use these
     counts to determine when every incoming boundary has reconnected.
  3) _WaitForReconnections: Wait for every incoming boundary to reconnect.
  4) _Replay: Wait for every boundary to send a message indicating replay
     is finished, at which point we can clear deduplication lists and
     inform other workers that they are free to send normal messages.
  5) _NotRecoveryReplaying: Finished replay

ASSUMPTION: Recovery replay can happen at most once in the lifecycle of a
  worker.
*/
typedef struct recovery_RecoveryReplayer recovery_RecoveryReplayer;

/*
Notifications for TCP listeners.

For an example of using this class, please see the documentation for the
`TCPListener` actor.
*/
typedef struct net_TCPListenNotify net_TCPListenNotify;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_topology_PartitionAddresses_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_topology_PartitionAddresses_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_$36$122_U64_val topology_$36$122_U64_val;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_box collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_box;

typedef struct t2_USize_val_Bool_val t2_USize_val_Bool_val;

typedef struct u2_options__Option_ref_options__ErrorPrinter_ref u2_options__Option_ref_options__ErrorPrinter_ref;

typedef struct u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A set, built on top of a HashMap. This is implemented as map of an alias of
a type to itself
*/
typedef struct collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val;

typedef struct boundary_$10$15_pony_CPPKey_val boundary_$10$15_pony_CPPKey_val;

typedef struct t2_U8_val_topology_ProxyAddress_val t2_U8_val_topology_ProxyAddress_val;

typedef struct u2_cluster_manager_ClusterManager_tag_None_val u2_cluster_manager_ClusterManager_tag_None_val;

typedef struct topology_$36$135_U64_val topology_$36$135_U64_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_box collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_box;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct topology_$36$128 topology_$36$128;

typedef struct collections_HashEq_String_val collections_HashEq_String_val;

typedef struct boundary_DataReceiversSubscriber boundary_DataReceiversSubscriber;

typedef struct ArrayValues_options__Option_ref_Array_options__Option_ref_box ArrayValues_options__Option_ref_Array_options__Option_ref_box;

typedef struct tcp_sink_$41$6_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val tcp_sink_$41$6_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val;

typedef struct t2_U8_val_U8_val t2_U8_val_U8_val;

typedef struct boundary_$10$21 boundary_$10$21;

typedef struct ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_val ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_val;

typedef struct messages1__DoneShutdown messages1__DoneShutdown;

typedef struct t2_U64_val_topology_ProxyAddress_val t2_U64_val_topology_ProxyAddress_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_routing_RouteLogic_ref_routing_RouteLogic_ref_collections_HashIs_routing_RouteLogic_ref_val collections_HashMap_routing_RouteLogic_ref_routing_RouteLogic_ref_collections_HashIs_routing_RouteLogic_ref_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u3_t2_String_val_initialization_LocalTopology_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_initialization_LocalTopology_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_ref collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_ref;

typedef struct u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_collections__MapEmpty_val_collections__MapDeleted_val;

/*
The readable interface of a sequence.
*/
typedef struct ReadSeq_U8_val ReadSeq_U8_val;

typedef struct http_URLPartPath http_URLPartPath;

typedef struct ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_box ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_box;

typedef struct ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_val ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_val;

typedef struct ArrayValues_String_ref_Array_String_ref_ref ArrayValues_String_ref_Array_String_ref_ref;

typedef struct initialization_LocalTopologyInitializer initialization_LocalTopologyInitializer;

typedef struct files_FileSync files_FileSync;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct tcp_sink_$41$10 tcp_sink_$41$10;

/*
A doubly linked list.
*/
typedef struct collections_List_t2_Array_U8_val_val_USize_val collections_List_t2_Array_U8_val_val_USize_val;

/*
Iterate over the values in a list.
*/
typedef struct collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_box collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_box;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct messages_EncoderWrapper messages_EncoderWrapper;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_ref collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_ref;

typedef struct topology_Runner topology_Runner;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_val collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_val;

typedef struct pony_CPPData pony_CPPData;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_val collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_val;

typedef struct tcp_sink_TCPSinkNotify tcp_sink_TCPSinkNotify;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_box collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_box;

typedef struct messages_TopologyReadyMsg messages_TopologyReadyMsg;

typedef struct u3_t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_$36$117 topology_$36$117;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct recovery__NotRecoveryReplaying recovery__NotRecoveryReplaying;

typedef struct u2_topology_OmniRouter_val_None_val u2_topology_OmniRouter_val_None_val;

typedef struct topology_LocalPartitionRouter_pony_CPPData_val_pony_CPPKey_val topology_LocalPartitionRouter_pony_CPPData_val_pony_CPPKey_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct t2_USize_val_U64_val t2_USize_val_U64_val;

typedef struct u3_t2_String_val_u4_None_val_String_val_I64_val_F64_val_options_ParseError_ref_None_val u3_t2_String_val_u4_None_val_String_val_I64_val_F64_val_options_ParseError_ref_None_val;

typedef struct t2_None_val_None_val t2_None_val_None_val;

typedef struct topology_AugmentablePartitionRouter_U64_val topology_AugmentablePartitionRouter_U64_val;

typedef struct boundary_OutgoingBoundaryBuilder boundary_OutgoingBoundaryBuilder;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_ref collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_ref;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_ref collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_ref;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_U8_val Array_U8_val;

typedef struct boundary_$10$12 boundary_$10$12;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct messages1_ExternalTopologyReadyMsg messages1_ExternalTopologyReadyMsg;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_val collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_val;

typedef struct options_I64Argument options_I64Argument;

typedef struct t2_u2_pony_CPPData_val_None_val_u2_topology_StateChange_pony_CPPState_ref_ref_None_val t2_u2_pony_CPPData_val_None_val_u2_topology_StateChange_pony_CPPState_ref_ref_None_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_tcp_source_TCPSourceListenerBuilder_val Array_tcp_source_TCPSourceListenerBuilder_val;

typedef struct t2_U64_val_routing__Route_ref t2_U64_val_routing__Route_ref;

typedef struct recovery__BoundaryMsgReplay recovery__BoundaryMsgReplay;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_ref collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_ref;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val;

typedef struct metrics_MetricsReporter metrics_MetricsReporter;

typedef struct u3_t2_time_Timer_tag_time_Timer_box_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_time_Timer_tag_time_Timer_box_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct routing_RouteLogic routing_RouteLogic;

typedef struct ArrayValues_U8_val_Array_U8_val_val ArrayValues_U8_val_Array_U8_val_val;

typedef struct u2_net_TCPConnection_tag_None_val u2_net_TCPConnection_tag_None_val;

typedef struct routing_$35$75_pony_CPPData_val_topology_StateProcessor_pony_CPPState_ref_val routing_$35$75_pony_CPPData_val_topology_StateProcessor_pony_CPPState_ref_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct ArrayValues_U128_val_Array_U128_val_ref ArrayValues_U128_val_Array_U128_val_ref;

typedef struct t2_ISize_val_String_iso t2_ISize_val_String_iso;

typedef struct network_$33$26 network_$33$26;

typedef struct u9_messages1_ExternalDataMsg_val_messages1_ExternalReadyMsg_val_messages1_ExternalTopologyReadyMsg_val_messages1_ExternalStartMsg_val_messages1_ExternalShutdownMsg_val_messages1_ExternalDoneShutdownMsg_val_messages1_ExternalDoneMsg_val_messages1_ExternalStartGilesSendersMsg_val_messages1_ExternalGilesSendersStartedMsg_val u9_messages1_ExternalDataMsg_val_messages1_ExternalReadyMsg_val_messages1_ExternalTopologyReadyMsg_val_messages1_ExternalStartMsg_val_messages1_ExternalShutdownMsg_val_messages1_ExternalDoneShutdownMsg_val_messages1_ExternalDoneMsg_val_messages1_ExternalStartGilesSendersMsg_val_messages1_ExternalGilesSendersStartedMsg_val;

typedef struct topology_$36$7_pony_CPPState_ref topology_$36$7_pony_CPPState_ref;

typedef struct topology_RunnerBuilder topology_RunnerBuilder;

typedef struct topology_$36$124_U8_val topology_$36$124_U8_val;

typedef struct topology_KeyedPartitionAddresses_pony_CPPKey_val topology_KeyedPartitionAddresses_pony_CPPKey_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_ref collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_ref;

typedef struct t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag;

/*
Manages a persistent and possibly pipelined TCP connection to an HTTP server.
*/
typedef struct http__ClientConnection http__ClientConnection;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_routing_Consumer_tag_routing_Route_ref_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_routing_Consumer_tag_routing_Route_ref_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u3_t2_Any_tag_Any_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_Any_tag_Any_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val;

typedef struct network_JoiningConnectNotifier network_JoiningConnectNotifier;

typedef struct initialization_$15$54 initialization_$15$54;

typedef struct u3_t2_String_val_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct boundary__TimerInit boundary__TimerInit;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_box collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_box;

typedef struct u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val;

/*
# TCPSourceListener
*/
typedef struct tcp_source_TCPSourceListener tcp_source_TCPSourceListener;

typedef struct u2_Array_String_val_val_None_val u2_Array_String_val_val_None_val;

typedef struct u2_Array_String_val_val_String_val u2_Array_String_val_val_String_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct recovery_$37$31_String_val_U128_val recovery_$37$31_String_val_U128_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct recovery_$37$16 recovery_$37$16;

typedef struct topology_Router topology_Router;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_ref collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_ref;

typedef struct ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_val ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_val;

typedef struct u3_t2_boundary__BoundaryId_val_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_boundary__BoundaryId_val_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct options_UnrecognisedOption options_UnrecognisedOption;

/*
A doubly linked list.
*/
typedef struct collections_List_time_Timer_ref collections_List_time_Timer_ref;

/*
# TCPSink

`TCPSink` replaces the Pony standard library class `TCPConnection`
within Wallaroo for outgoing connections to external systems. While
`TCPConnection` offers a number of excellent features it doesn't
account for our needs around resilience.

`TCPSink` incorporates basic send/recv functionality from `TCPConnection` as
well working with our upstream backup/message acknowledgement system.

## Resilience and message tracking

...

## Possible future work

- Much better algo for determining how many credits to hand out per producer
- At the moment we treat sending over TCP as done. In the future we can and should support ack of the data being handled from the other side.
- Handle reconnecting after being disconnected from the downstream
- Optional in sink deduplication (this woud involve storing what we sent and
  was acknowleged.)
*/
typedef struct tcp_sink_TCPSink tcp_sink_TCPSink;

typedef struct boundary_$10$17_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val boundary_$10$17_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val;

typedef struct t2_Any_tag_Any_tag t2_Any_tag_Any_tag;

typedef struct recovery_$37$12 recovery_$37$12;

typedef struct pony_CPPStateComputationReturnPairWrapper pony_CPPStateComputationReturnPairWrapper;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct wallaroo_$19$26 wallaroo_$19$26;

typedef struct topology_$36$113_pony_CPPData_val_pony_CPPKey_val topology_$36$113_pony_CPPData_val_pony_CPPKey_val;

typedef struct u2_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_None_val u2_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_None_val;

/*
Phases:
  1) _NotRecovering: Waiting for start_recovery() to be called
  2) _LogReplay: Wait for EventLog to finish replaying the event logs
  3) _BoundaryMsgReplay: Wait for RecoveryReplayer to manage message replay
     from incoming boundaries.
  4) _NotRecovering: Finished recovery
*/
typedef struct recovery_Recovery recovery_Recovery;

typedef struct u2_topology_StateSubpartition_val_None_val u2_topology_StateSubpartition_val_None_val;

typedef struct routing_$35$96_topology_StateProcessor_pony_CPPState_ref_val routing_$35$96_topology_StateProcessor_pony_CPPState_ref_val;

typedef struct wallaroo_$19$29 wallaroo_$19$29;

typedef struct topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_pony_CPPKey_val topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_pony_CPPKey_val;

typedef struct routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_pony_CPPData_val routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_pony_CPPData_val;

typedef struct files_FileError files_FileError;

typedef struct collections_HashEq_USize_val collections_HashEq_USize_val;

typedef struct t2_U16_val_String_val t2_U16_val_String_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_ref collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_ref;

typedef struct pony_CPPStateComputation pony_CPPStateComputation;

typedef struct boundary__BoundaryId boundary__BoundaryId;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_box collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_box;

typedef struct t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_ref collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_ref;

/*
Flags is a set of flags. The flags that are recognised should be passed as
a union type for type parameter A. For example:

primitive SSE
  fun value(): U64 => 1

primitive AVX
  fun value(): U64 => 2

primitive RDTSCP
  fun value(): U64 => 4

type Features is Flags[(SSE | AVX | RDTSCP)]

Type parameter B is the unlying field used to store the flags.
*/
typedef struct collections_Flags_u16_files_FileCreate_val_files_FileChmod_val_files_FileChown_val_files_FileLink_val_files_FileLookup_val_files_FileMkdir_val_files_FileRead_val_files_FileRemove_val_files_FileRename_val_files_FileSeek_val_files_FileStat_val_files_FileSync_val_files_FileTime_val_files_FileTruncate_val_files_FileWrite_val_files_FileExec_val_U32_val collections_Flags_u16_files_FileCreate_val_files_FileChmod_val_files_FileChown_val_files_FileLink_val_files_FileLookup_val_files_FileMkdir_val_files_FileRead_val_files_FileRemove_val_files_FileRename_val_files_FileSeek_val_files_FileStat_val_files_FileSync_val_files_FileTime_val_files_FileTruncate_val_files_FileWrite_val_files_FileExec_val_U32_val;

typedef struct ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_box ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_box;

typedef struct u2_topology_Step_tag_None_val u2_topology_Step_tag_None_val;

/*
A collection of ways to fetch the current time.
*/
typedef struct time_Time time_Time;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_box collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_box;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct t2_routing_RouteLogic_box_routing_RouteLogic_box t2_routing_RouteLogic_box_routing_RouteLogic_box;

typedef struct boundary_$10$18_pony_CPPData_val boundary_$10$18_pony_CPPData_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_U32_val Array_U32_val;

typedef struct files__PathDot2 files__PathDot2;

typedef struct ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_box ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_box;

typedef struct recovery_$37$18 recovery_$37$18;

typedef struct topology_$36$120 topology_$36$120;

typedef struct topology_ProxyAddress topology_ProxyAddress;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_val collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_val;

typedef struct u3_t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_SerializableStateRunner topology_SerializableStateRunner;

typedef struct u2_Array_t2_pony_CPPKey_val_USize_val_val_Array_pony_CPPKey_val_val u2_Array_t2_pony_CPPKey_val_USize_val_val_Array_pony_CPPKey_val_val;

typedef struct guid_GuidGenerator guid_GuidGenerator;

typedef struct messages_ReplayMsg messages_ReplayMsg;

typedef struct files_FileExec files_FileExec;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u3_t2_http__HostService_val_http__ClientConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_http__HostService_val_http__ClientConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct t2_String_val_boundary_OutgoingBoundaryBuilder_val t2_String_val_boundary_OutgoingBoundaryBuilder_val;

typedef struct u4_AmbientAuth_val_net_NetAuth_val_net_DNSAuth_val_None_val u4_AmbientAuth_val_net_NetAuth_val_net_DNSAuth_val_None_val;

typedef struct routing_Consumer routing_Consumer;

typedef struct t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref;

typedef struct topology_PartitionFunction_pony_CPPData_val_pony_CPPKey_val topology_PartitionFunction_pony_CPPData_val_pony_CPPKey_val;

typedef struct net_TCPAuth net_TCPAuth;

typedef struct t2_U16_val_USize_val t2_U16_val_USize_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_box collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_box;

typedef struct topology_StepIdRouter topology_StepIdRouter;

typedef struct files_FileSeek files_FileSeek;

typedef struct messages_UnknownChannelMsg messages_UnknownChannelMsg;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_ref collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_ref;

/*
A set, built on top of a HashMap. This is implemented as map of an alias of
a type to itself
*/
typedef struct collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_box collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_box;

typedef struct recovery__EmptyReplayPhase recovery__EmptyReplayPhase;

typedef struct t2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val t2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_val collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_val;

/*
Functions for asynchronous event notification.
*/
typedef struct AsioEvent AsioEvent;

typedef struct collections__MapEmpty collections__MapEmpty;

typedef struct u2_collections_List_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val u2_collections_List_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val;

typedef struct recovery_DummyBackend recovery_DummyBackend;

typedef struct topology_StateComputation_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref topology_StateComputation_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref;

typedef struct data_channel__DataReceiverWrapper data_channel__DataReceiverWrapper;

typedef struct recovery_FileBackend recovery_FileBackend;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_boundary_OutgoingBoundaryBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_boundary_OutgoingBoundaryBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct network_$33$36 network_$33$36;

typedef struct t2_http__HostService_val_http__ClientConnection_tag t2_http__HostService_val_http__ClientConnection_tag;

typedef struct u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
Notifications for DataChannel connections.

For an example of using this class please see the documentation for the
`DataChannel` and `DataChannelListener` actors.
*/
typedef struct data_channel_DataChannelNotify data_channel_DataChannelNotify;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_Array_U64_val_ref Array_Array_U64_val_ref;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_ref collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_ref;

typedef struct t2_routing_Consumer_tag_routing_Route_val t2_routing_Consumer_tag_routing_Route_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U8_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U8_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val;

typedef struct initialization_$15$70 initialization_$15$70;

typedef struct t2_String_val_None_val t2_String_val_None_val;

typedef struct u3_t2_U128_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U128_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_box ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_box;

typedef struct u2_collections_List_t2_USize_val_U64_val_ref_None_val u2_collections_List_t2_USize_val_U64_val_ref_None_val;

typedef struct t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val;

typedef struct topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_U64_val_pony_CPPState_ref topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_U64_val_pony_CPPState_ref;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_net_TCPConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_net_TCPConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u2_Array_String_val_ref_None_val u2_Array_String_val_ref_None_val;

typedef struct topology_PartitionFunction_pony_CPPData_val_U64_val topology_PartitionFunction_pony_CPPData_val_U64_val;

typedef struct topology_$36$119_U64_val topology_$36$119_U64_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_ref collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_ref;

typedef struct t2_String_val_U128_val t2_String_val_U128_val;

typedef struct tcp_sink_$41$6_topology_StateProcessor_pony_CPPState_ref_val tcp_sink_$41$6_topology_StateProcessor_pony_CPPState_ref_val;

typedef struct initialization_$15$55 initialization_$15$55;

/*
# MetricsSink

`MetricsSink` replaces the Pony standard library class `TCPConnection`
within Wallaroo for outgoing connections for metrics. While
`TCPConnection` offers a number of excellent features it doesn't
account for our needs around encoding of output messages in the sink.

`MetricsSink` is a copy of `TCPConnection` with
support for a behavior for sending metrics.
*/
typedef struct metrics_MetricsSink metrics_MetricsSink;

typedef struct t3_U64_val_U128_val_topology_Step_tag t3_U64_val_U128_val_topology_Step_tag;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_val collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_val;

typedef struct topology_StateSubpartition topology_StateSubpartition;

typedef struct network_$33$34 network_$33$34;

typedef struct pony_CPPState pony_CPPState;

typedef struct topology_$36$96_topology_StateProcessor_pony_CPPState_ref_val topology_$36$96_topology_StateProcessor_pony_CPPState_ref_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_box collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_box;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections_HashEq_U128_val_val collections_HashMap_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections_HashEq_U128_val_val;

typedef struct u3_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u2_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_None_val u2_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_None_val;

typedef struct $0$13_U32_val $0$13_U32_val;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_ref collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_ref;

typedef struct t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_Array_U8_val_ref Array_Array_U8_val_ref;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct messages_TypedEncoderWrapper_pony_CPPData_val messages_TypedEncoderWrapper_pony_CPPData_val;

typedef struct t2_U64_val_Bool_val t2_U64_val_Bool_val;

typedef struct initialization_$15$51 initialization_$15$51;

typedef struct messages_KeyedStepMigrationMsg_pony_CPPKey_val messages_KeyedStepMigrationMsg_pony_CPPKey_val;

typedef struct t2_pony_CPPKey_val_U128_val t2_pony_CPPKey_val_U128_val;

typedef struct ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_val ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct $0$12_routing_Producer_tag $0$12_routing_Producer_tag;

typedef struct initialization_$15$63 initialization_$15$63;

typedef struct u2_collections_List_http_Payload_val_ref_None_val u2_collections_List_http_Payload_val_ref_None_val;

typedef struct topology_$36$122_U8_val topology_$36$122_U8_val;

typedef struct options_ParseError options_ParseError;

typedef struct network_Connections network_Connections;

typedef struct recovery_Backend recovery_Backend;

typedef struct boundary_DataReceivers boundary_DataReceivers;

typedef struct ArrayValues_U8_val_Array_U8_val_ref ArrayValues_U8_val_Array_U8_val_ref;

typedef struct collections__MapDeleted collections__MapDeleted;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_val collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_val;

typedef struct t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val;

typedef struct collections_HashEq_pony_CPPKey_val collections_HashEq_pony_CPPKey_val;

typedef struct t3_pony_CPPKey_val_U128_val_topology_Step_tag t3_pony_CPPKey_val_U128_val_topology_Step_tag;

typedef struct messages1_ExternalDoneMsg messages1_ExternalDoneMsg;

typedef struct http_URLPartFragment http_URLPartFragment;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_val collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_val;

typedef struct t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box;

typedef struct u4_None_val_options_StringArgument_val_options_I64Argument_val_options_F64Argument_val u4_None_val_options_StringArgument_val_options_I64Argument_val_options_F64Argument_val;

typedef struct u16_files_FileCreate_val_files_FileChmod_val_files_FileChown_val_files_FileLink_val_files_FileLookup_val_files_FileMkdir_val_files_FileRead_val_files_FileRemove_val_files_FileRename_val_files_FileSeek_val_files_FileStat_val_files_FileSync_val_files_FileTime_val_files_FileTruncate_val_files_FileWrite_val_files_FileExec_val u16_files_FileCreate_val_files_FileChmod_val_files_FileChown_val_files_FileLink_val_files_FileLookup_val_files_FileMkdir_val_files_FileRead_val_files_FileRemove_val_files_FileRename_val_files_FileSeek_val_files_FileStat_val_files_FileSync_val_files_FileTime_val_files_FileTruncate_val_files_FileWrite_val_files_FileExec_val;

typedef struct u2_tcp_sink_TCPSinkBuilder_val_None_val u2_tcp_sink_TCPSinkBuilder_val_None_val;

typedef struct u2_routing_RouteBuilder_val_None_val u2_routing_RouteBuilder_val_None_val;

typedef struct $0$1_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag $0$1_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_box collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_box;

typedef struct files__PathOther files__PathOther;

/*
This message is sent to notify another worker that a new stateful step has
been created on this worker and that partition routers should be updated.
*/
typedef struct messages_KeyedAnnounceNewStatefulStepMsg_pony_CPPKey_val messages_KeyedAnnounceNewStatefulStepMsg_pony_CPPKey_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct messages1__TopologyReady messages1__TopologyReady;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_val collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct topology_$36$105 topology_$36$105;

typedef struct t2_String_val_initialization_LocalTopology_val t2_String_val_initialization_LocalTopology_val;

typedef struct topology_$36$125_U64_val topology_$36$125_U64_val;

typedef struct ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_val ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val;

typedef struct u3_t2_routing_RouteLogic_box_routing_RouteLogic_box_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_routing_RouteLogic_box_routing_RouteLogic_box_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_ComputationBuilder_pony_CPPData_val_pony_CPPData_val topology_ComputationBuilder_pony_CPPData_val_pony_CPPData_val;

typedef struct topology_InputWrapper topology_InputWrapper;

typedef struct topology_$36$96_pony_CPPData_val topology_$36$96_pony_CPPData_val;

typedef struct ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_box ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_box;

typedef struct t2_USize_val_wallaroo_InitFile_val t2_USize_val_wallaroo_InitFile_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_ref collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_ref;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct topology_PartitionBuilder topology_PartitionBuilder;

/*
A set, built on top of a HashMap. This is implemented as map of an alias of
a type to itself
*/
typedef struct collections_HashSet_Any_tag_collections_HashIs_Any_tag_val collections_HashSet_Any_tag_collections_HashIs_Any_tag_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct routing_DataReceiverRoutes routing_DataReceiverRoutes;

typedef struct t2_String_val_topology_PartitionRouter_val t2_String_val_topology_PartitionRouter_val;

typedef struct topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_U64_val topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_U64_val;

typedef struct boundary_$10$15_U8_val boundary_$10$15_U8_val;

typedef struct u2_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_None_val u2_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_None_val;

typedef struct topology_Computation_pony_CPPData_val_pony_CPPData_val topology_Computation_pony_CPPData_val_pony_CPPData_val;

/*
Relationship between a single producer and a single consumer.
*/
typedef struct routing_TypedRoute_pony_CPPData_val routing_TypedRoute_pony_CPPData_val;

typedef struct files_FileWrite files_FileWrite;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_box collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_box;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_t3_U64_val_U128_val_topology_Step_tag Array_t3_U64_val_U128_val_topology_Step_tag;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_USize_val_wallaroo_InitFile_val_collections_HashEq_USize_val_val collections_HashMap_USize_val_wallaroo_InitFile_val_collections_HashEq_USize_val_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U128_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U128_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct Less Less;

typedef struct u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val;

typedef struct topology__StringSet topology__StringSet;

typedef struct u4_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_None_val u4_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_None_val;

typedef struct options_StringArgument options_StringArgument;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U64_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U64_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct network_WallarooOutgoingNetworkActor network_WallarooOutgoingNetworkActor;

typedef struct u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U64_val_Bool_val_collections_HashEq_U64_val_val collections_HashMap_U64_val_Bool_val_collections_HashEq_U64_val_val;

typedef struct ssl__SSLContext ssl__SSLContext;

/*
Notifications for DataChannel listeners.

For an example of using this class, please see the documentation for the
`DataChannelListener` actor.
*/
typedef struct data_channel_DataChannelListenNotify data_channel_DataChannelListenNotify;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_String_val_collections_HashIs_String_val_val collections_HashMap_String_val_String_val_collections_HashIs_String_val_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_val collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_Pointer_U8_val_tag Array_Pointer_U8_val_tag;

/*
The sole purpose of this listener is to keep a joining worker process alive
while waiting to get cluster info and initialize.
TODO: Eliminate the need for this.
*/
typedef struct network_JoiningListenNotifier network_JoiningListenNotifier;

typedef struct t2_collections_ListNode_time_Timer_ref_ref_None_val t2_collections_ListNode_time_Timer_ref_ref_None_val;

typedef struct t2_routing_Consumer_tag_routing_Route_ref t2_routing_Consumer_tag_routing_Route_ref;

typedef struct topology_$36$96_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val topology_$36$96_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val;

typedef struct routing_$35$72_topology_StateProcessor_pony_CPPState_ref_val routing_$35$72_topology_StateProcessor_pony_CPPState_ref_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_ref collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_ref;

typedef struct u2_wallaroo_Application_val_None_val u2_wallaroo_Application_val_None_val;

typedef struct topology_SingleStepPartitionFunction_pony_CPPData_val topology_SingleStepPartitionFunction_pony_CPPData_val;

/*
A Histogram where each value is counted into the bin of its next power of 2
value. e.g. 3->bin:4, 4->bin:4, 5->bin:8, etc.

In addition to the histogram itself, we are storing the min, max_value
and total number of values seen (throughput) for reporting.
*/
typedef struct metrics_Histogram metrics_Histogram;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_ref collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_ref;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_topology_Initializable_tag_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val collections_HashMap_topology_Initializable_tag_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val;

typedef struct routing_$35$76_topology_StateProcessor_pony_CPPState_ref_val routing_$35$76_topology_StateProcessor_pony_CPPState_ref_val;

typedef struct t2_String_val_metrics__MetricsReporter_ref t2_String_val_metrics__MetricsReporter_ref;

typedef struct data_channel_$45$7 data_channel_$45$7;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_ref collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_ref;

typedef struct u2_u2_topology_ProxyAddress_val_U128_val_None_val u2_u2_topology_ProxyAddress_val_U128_val_None_val;

typedef struct topology_Partition_pony_CPPData_val_U8_val topology_Partition_pony_CPPData_val_U8_val;

typedef struct tcp_sink_EmptySink tcp_sink_EmptySink;

typedef struct Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val;

typedef struct topology_$36$112_pony_CPPData_val_U8_val topology_$36$112_pony_CPPData_val_U8_val;

typedef struct initialization_$15$73 initialization_$15$73;

typedef struct u2_Array_t2_U8_val_USize_val_val_Array_U8_val_val u2_Array_t2_U8_val_USize_val_val_Array_U8_val_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct boundary_$10$16 boundary_$10$16;

typedef struct t2_u2_options__Option_ref_None_val_USize_val t2_u2_options__Option_ref_None_val_USize_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct files__EBADF files__EBADF;

typedef struct messages1_ExternalDoneShutdownMsg messages1_ExternalDoneShutdownMsg;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box;

typedef struct routing__FilterRoute routing__FilterRoute;

typedef struct recovery_$37$14 recovery_$37$14;

typedef struct topology_DataRouter topology_DataRouter;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
Manages a collection of client connections.
*/
typedef struct http_Client http_Client;

/*
Asynchronous access to stdin. The constructor is private to ensure that
access is provided only via an environment.
*/
typedef struct Stdin Stdin;

typedef struct data_channel_$45$10 data_channel_$45$10;

/*
Relationship between a single producer and a single consumer.
*/
typedef struct routing_BoundaryRoute routing_BoundaryRoute;

typedef struct cluster_manager_DockerSwarmWorkerResponseHandler cluster_manager_DockerSwarmWorkerResponseHandler;

typedef struct initialization_$15$60 initialization_$15$60;

typedef struct pony_CPPSinkEncoder pony_CPPSinkEncoder;

typedef struct pony_WallarooMain pony_WallarooMain;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_ref ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_ref;

typedef struct pony_CPPPartitionFunctionU64 pony_CPPPartitionFunctionU64;

typedef struct routing_$35$72_pony_CPPData_val routing_$35$72_pony_CPPData_val;

typedef struct routing_$35$94 routing_$35$94;

typedef struct u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct boundary__DataReceiverAcceptingMessagesPhase boundary__DataReceiverAcceptingMessagesPhase;

typedef struct u2_boundary_DataReceiver_tag_None_val u2_boundary_DataReceiver_tag_None_val;

typedef struct ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_val ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_val;

/*
A set, built on top of a HashMap. This is implemented as map of an alias of
a type to itself
*/
typedef struct collections_HashSet_String_val_collections_HashEq_String_val_val collections_HashSet_String_val_collections_HashEq_String_val_val;

typedef struct messages_SpinUpLocalTopologyMsg messages_SpinUpLocalTopologyMsg;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_time__TimingWheel_ref Array_time__TimingWheel_ref;

typedef struct routing_TypedRouteBuilder_topology_StateProcessor_pony_CPPState_ref_val routing_TypedRouteBuilder_topology_StateProcessor_pony_CPPState_ref_val;

typedef struct routing_$35$73 routing_$35$73;

typedef struct data_channel__InitDataReceiver data_channel__InitDataReceiver;

typedef struct routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val;

typedef struct messages_AckWatermarkMsg messages_AckWatermarkMsg;

typedef struct u3_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val u3_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_routing_Producer_tag Array_routing_Producer_tag;

typedef struct i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct options__Option options__Option;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_topology_PartitionRouter_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_topology_PartitionRouter_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_boundary_OutgoingBoundary_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_boundary_OutgoingBoundary_tag_collections__MapEmpty_val_collections__MapDeleted_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u3_t2_String_val_topology_PartitionBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_topology_PartitionBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct files_FileCreate files_FileCreate;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_box collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_box;

typedef struct u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct routing_$35$78 routing_$35$78;

/*
Relationship between a single producer and a single consumer.
*/
typedef struct routing_TypedRoute_topology_StateProcessor_pony_CPPState_ref_val routing_TypedRoute_topology_StateProcessor_pony_CPPState_ref_val;

typedef struct t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag;

typedef struct t6_U128_val_U128_val_None_val_U64_val_U64_val_Array_U8_val_val t6_U128_val_U128_val_None_val_U64_val_U64_val_Array_U8_val_val;

typedef struct topology_$36$129 topology_$36$129;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u3_t2_String_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_USize_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_USize_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct network_$33$24_U8_val network_$33$24_U8_val;

typedef struct ArrayValues_U128_val_Array_U128_val_val ArrayValues_U128_val_Array_U128_val_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_String_val_collections_HashEq_String_val_val collections_HashMap_String_val_String_val_collections_HashEq_String_val_val;

typedef struct $0$0_routing_Producer_tag $0$0_routing_Producer_tag;

typedef struct messages_IdentifyControlPortMsg messages_IdentifyControlPortMsg;

typedef struct net_TCPListenAuth net_TCPListenAuth;

typedef struct ArrayValues_U128_val_Array_U128_val_box ArrayValues_U128_val_Array_U128_val_box;

typedef struct http__HostService http__HostService;

typedef struct topology_StateRunnerBuilder_pony_CPPState_ref topology_StateRunnerBuilder_pony_CPPState_ref;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_topology_Router_val_collections_HashEq_String_val_val collections_HashMap_String_val_topology_Router_val_collections_HashEq_String_val_val;

typedef struct routing_$35$77 routing_$35$77;

/*
A node in a list.
*/
typedef struct collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val;

typedef struct i2_recovery_Resilient_tag_routing_Producer_tag i2_recovery_Resilient_tag_routing_Producer_tag;

typedef struct u3_t2_pony_CPPKey_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_pony_CPPKey_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u3_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_None_val u3_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_None_val;

typedef struct messages1_ExternalMsg messages1_ExternalMsg;

typedef struct ArrayValues_String_val_Array_String_val_val ArrayValues_String_val_Array_String_val_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct t2_String_val_F64_val t2_String_val_F64_val;

/*
Iterate over the values in a list.
*/
typedef struct collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_val collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_val;

typedef struct messages_ChannelMsg messages_ChannelMsg;

typedef struct u4_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val_net_TCPConnectAuth_val u4_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val_net_TCPConnectAuth_val;

typedef struct initialization_LocalTopology initialization_LocalTopology;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_val collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_val;

typedef struct messages_StepMigrationMsg messages_StepMigrationMsg;

typedef struct t2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref t2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val;

typedef struct StringRunes StringRunes;

typedef struct messages_SinkEncoder_pony_CPPData_val messages_SinkEncoder_pony_CPPData_val;

typedef struct t2_String_val_topology_PartitionBuilder_val t2_String_val_topology_PartitionBuilder_val;

typedef struct pony_CPPStateChangeBuilder pony_CPPStateChangeBuilder;

/*
Store network data and provide a parsing interface.

`Reader` provides a way to extract typed data from a sequence of
bytes. The `Reader` manages the underlying data structures to
provide a read cursor over a contiguous sequence of bytes. It is
useful for decoding data that is received over a network or stored
in a file. Chunk of bytes are added to the `Reader` using the
`append` method, and typed data is extracted using the getter
methods.

For example, suppose we have a UDP-based network data protocol where
messages consist of the following:

* `list_size` - the number of items in the following list of items
  as a big-endian 32-bit integer
* zero or more items of the following data:
  * a big-endian 64-bit floating point number
  * a string that starts with a big-endian 32-bit integer that
    specifies the length of the string, followed by a number of
    bytes that represent the string

A message would be something like this:

```
[message_length][list_size][float1][string1][float2][string2]...
```

The following program uses a `Reader` to decode a message of
this type and print them:

```
use "net"
use "collections"

class Notify is StdinNotify
  let _env: Env
  new create(env: Env) =>
    _env = env
  fun ref apply(data: Array[U8] iso) =>
    let rb = Reader
    rb.append(consume data)
    try
      while true do
        let len = rb.i32_be()
        let items = rb.i32_be().usize()
        for range in Range(0, items) do
          let f = rb.f32_be()
          let str_len = rb.i32_be().usize()
          let str = String.from_array(rb.block(str_len))
          _env.out.print("[(" + f.string() + "), (" + str + ")]")
        end
      end
    end

actor Main
  new create(env: Env) =>
    env.input(recover Notify(env) end, 1024)
```
*/
typedef struct buffered_Reader buffered_Reader;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_box collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_box;

typedef struct options_F64Argument options_F64Argument;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_ComputationRunnerBuilder_pony_CPPData_val_pony_CPPData_val topology_ComputationRunnerBuilder_pony_CPPData_val_pony_CPPData_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct messages_ChannelMsgDecoder messages_ChannelMsgDecoder;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_box collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_box;

typedef struct ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_ref ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_ref;

typedef struct files_FileExists files_FileExists;

typedef struct u2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_None_val u2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_None_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_ref collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_ref;

typedef struct network_$33$33 network_$33$33;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_box collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_box;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_box collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_box;

typedef struct messages_ForwardMsg_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val messages_ForwardMsg_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val;

typedef struct u2_None_val_pony_CPPData_val u2_None_val_pony_CPPData_val;

typedef struct network_JoiningControlSenderConnectNotifier network_JoiningControlSenderConnectNotifier;

typedef struct topology_$36$135_U8_val topology_$36$135_U8_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct tcp_source_SourceBuilder tcp_source_SourceBuilder;

typedef struct messages_AckDataConnectMsg messages_AckDataConnectMsg;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_val collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_topology_Initializable_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_topology_Initializable_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_RouterRegistry topology_RouterRegistry;

typedef struct u2_Greater_val_Less_val u2_Greater_val_Less_val;

typedef struct topology_StateRunner_pony_CPPState_ref topology_StateRunner_pony_CPPState_ref;

typedef struct t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box;

typedef struct options_Options options_Options;

typedef struct topology_$36$118 topology_$36$118;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_net_TCPListener_tag Array_net_TCPListener_tag;

typedef struct ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_val ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_val;

typedef struct ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_box ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_box;

typedef struct u2_String_val_None_val u2_String_val_None_val;

typedef struct u2_net_TCPListener_tag_data_channel_DataChannelListener_tag u2_net_TCPListener_tag_data_channel_DataChannelListener_tag;

/*
Operations on paths that do not require a capability. The operations can be
used to manipulate path names, but give no access to the resulting paths.
*/
typedef struct files_Path files_Path;

/*
This contains file system metadata for a path. The times are in the same
format as Time.now(), i.e. seconds and nanoseconds since the epoch.

The UID and GID are UNIX-style user and group IDs. These will be zero on
Windows. The change_time will actually be the file creation time on Windows.

A symlink will report information about itself, other than the size which
will be the size of the target. A broken symlink will report as much as it
can and will set the broken flag.
*/
typedef struct files_FileInfo files_FileInfo;

typedef struct u3_t2_U64_val_routing__Route_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U64_val_routing__Route_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct boundary_$10$28 boundary_$10$28;

typedef struct topology_$36$123_pony_CPPKey_val topology_$36$123_pony_CPPKey_val;

typedef struct ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_val ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_val;

typedef struct t2_boundary__BoundaryId_box_boundary_DataReceiver_tag t2_boundary__BoundaryId_box_boundary_DataReceiver_tag;

typedef struct collections_HashIs_boundary_DataReceiversSubscriber_tag collections_HashIs_boundary_DataReceiversSubscriber_tag;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_box collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_box;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u3_t2_routing_RouteLogic_val_routing_RouteLogic_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_routing_RouteLogic_val_routing_RouteLogic_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct pony_CPPApplicationBuilder pony_CPPApplicationBuilder;

typedef struct t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_ref collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_ref;

typedef struct dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val;

typedef struct files__EACCES files__EACCES;

typedef struct metrics_PauseBeforeReconnect metrics_PauseBeforeReconnect;

typedef struct ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_val ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_val;

typedef struct t2_pony_CPPKey_val_topology_ProxyAddress_val t2_pony_CPPKey_val_topology_ProxyAddress_val;

/*
A set, built on top of a HashMap. This is implemented as map of an alias of
a type to itself
*/
typedef struct collections_HashSet_data_channel_DataChannelListener_tag_collections_HashIs_data_channel_DataChannelListener_tag_val collections_HashSet_data_channel_DataChannelListener_tag_collections_HashIs_data_channel_DataChannelListener_tag_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_val collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_val;

typedef struct messages_UnmuteRequestMsg messages_UnmuteRequestMsg;

typedef struct collections_HashIs_routing_Consumer_tag collections_HashIs_routing_Consumer_tag;

typedef struct collections_HashIs_routing_RouteLogic_ref collections_HashIs_routing_RouteLogic_ref;

typedef struct t2_String_val_String_iso t2_String_val_String_iso;

typedef struct boundary__DataReceiverNotProcessingPhase boundary__DataReceiverNotProcessingPhase;

typedef struct u2_String_val_Array_String_val_val u2_String_val_Array_String_val_val;

typedef struct options_InvalidArgument options_InvalidArgument;

typedef struct t2_String_val_topology_StateSubpartition_val t2_String_val_topology_StateSubpartition_val;

typedef struct boundary_$10$23 boundary_$10$23;

typedef struct messages1_ExternalReadyMsg messages1_ExternalReadyMsg;

typedef struct t2_u2_pony_CPPData_val_None_val_u2_pony_CPPStateChange_ref_None_val t2_u2_pony_CPPData_val_None_val_u2_pony_CPPStateChange_ref_None_val;

typedef struct messages_ReplayableDeliveryMsg messages_ReplayableDeliveryMsg;

typedef struct u2_U128_val_None_val u2_U128_val_None_val;

typedef struct routing__OutgoingToIncoming routing__OutgoingToIncoming;

typedef struct t2_String_val_USize_val t2_String_val_USize_val;

typedef struct files_FileBadFileNumber files_FileBadFileNumber;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct initialization_$15$64 initialization_$15$64;

typedef struct u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_http__HostService_val_http__ClientConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_http__HostService_val_http__ClientConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_box ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_box;

typedef struct routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_pony_CPPData_val routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_pony_CPPData_val;

typedef struct ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_box ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_box;

typedef struct u2_topology_RunnerBuilder_val_None_val u2_topology_RunnerBuilder_val_None_val;

typedef struct u3_t2_U128_val_u2_topology_ProxyAddress_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U128_val_u2_topology_ProxyAddress_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct wallaroo_PipelineBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val wallaroo_PipelineBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_val collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_val;

typedef struct ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_ref ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_ref;

typedef struct initialization_$15$50 initialization_$15$50;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct t2_U128_val_topology_StepBuilder_val t2_U128_val_topology_StepBuilder_val;

typedef struct ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_val ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_val;

typedef struct tcp_source_TCPSourceNotify tcp_source_TCPSourceNotify;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_data_channel_DataChannelListener_tag Array_data_channel_DataChannelListener_tag;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val;

/*
A set, built on top of a HashMap. This is implemented as map of an alias of
a type to itself
*/
typedef struct collections_HashSet_net_TCPListener_tag_collections_HashIs_net_TCPListener_tag_val collections_HashSet_net_TCPListener_tag_collections_HashIs_net_TCPListener_tag_val;

typedef struct ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_ref ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_ref;

typedef struct t2_U128_val_u2_topology_ProxyAddress_val_U128_val t2_U128_val_u2_topology_ProxyAddress_val_U128_val;

typedef struct routing__EmptyRouteLogic routing__EmptyRouteLogic;

typedef struct files__EEXIST files__EEXIST;

typedef struct topology_$36$119_pony_CPPKey_val topology_$36$119_pony_CPPKey_val;

typedef struct Any Any;

typedef struct network_$33$38 network_$33$38;

typedef struct u2_t2_String_val_String_val_None_val u2_t2_String_val_String_val_None_val;

typedef struct $0$1_routing_Producer_tag $0$1_routing_Producer_tag;

typedef struct routing_Route routing_Route;

typedef struct u3_t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct boundary_$10$15_U64_val boundary_$10$15_U64_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct initialization_$15$69 initialization_$15$69;

/*
Listens for new network connections.

The following program creates an echo server that listens for
connections on port 8989 and echoes back any data it receives.

```
use "net"

class MyTCPConnectionNotify is TCPConnectionNotify
  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    conn.write(String.from_array(consume data))

class MyTCPListenNotify is TCPListenNotify
  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    MyTCPConnectionNotify

actor Main
  new create(env: Env) =>
    try
      TCPListener(env.root as AmbientAuth,
        recover MyTCPListenNotify end, "", "8989")
    end
```
*/
typedef struct net_TCPListener net_TCPListener;

typedef struct u2_initialization_LocalTopologyInitializer_tag_None_val u2_initialization_LocalTopologyInitializer_tag_None_val;

typedef struct tcp_sink_PauseBeforeReconnectTCPSink tcp_sink_PauseBeforeReconnectTCPSink;

typedef struct options_MissingArgument options_MissingArgument;

typedef struct topology_StateBuilder_pony_CPPState_ref topology_StateBuilder_pony_CPPState_ref;

typedef struct topology_ReplayableRunner topology_ReplayableRunner;

typedef struct t2_String_val_net_TCPConnection_tag t2_String_val_net_TCPConnection_tag;

typedef struct recovery_$37$17 recovery_$37$17;

typedef struct u3_t2_String_val_USize_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_USize_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u3_t2_topology_Step_tag_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_topology_Step_tag_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct messages_JoiningWorkerInitializedMsg messages_JoiningWorkerInitializedMsg;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_val collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct files_FileMkdir files_FileMkdir;

typedef struct messages1__Start messages1__Start;

typedef struct messages_ForwardMsg_topology_StateProcessor_pony_CPPState_ref_val messages_ForwardMsg_topology_StateProcessor_pony_CPPState_ref_val;

typedef struct tcp_source_TypedSourceBuilderBuilder_pony_CPPData_val tcp_source_TypedSourceBuilderBuilder_pony_CPPData_val;

typedef struct wallaroo_StartupHelp wallaroo_StartupHelp;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_topology_StateChangeBuilder_pony_CPPState_ref_val Array_topology_StateChangeBuilder_pony_CPPState_ref_val;

typedef struct ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_val ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_val;

typedef struct messages1_ExternalMsgDecoder messages1_ExternalMsgDecoder;

typedef struct recovery__LogReplay recovery__LogReplay;

typedef struct routing_$35$76_pony_CPPData_val routing_$35$76_pony_CPPData_val;

typedef struct wallaroo_$19$30 wallaroo_$19$30;

typedef struct u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val;

typedef struct ArrayValues_String_ref_Array_String_ref_val ArrayValues_String_ref_Array_String_ref_val;

/*
A node in a list.
*/
typedef struct collections_ListNode_t2_Array_U8_val_val_USize_val collections_ListNode_t2_Array_U8_val_val_USize_val;

typedef struct u3_t2_U64_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U64_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u2_boundary_OutgoingBoundaryBuilder_val_None_val u2_boundary_OutgoingBoundaryBuilder_val_None_val;

typedef struct u2_network_Connections_tag_None_val u2_network_Connections_tag_None_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_val collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_val;

typedef struct t6_Bool_val_Bool_val_u2_topology_StateChange_pony_CPPState_ref_ref_None_val_U64_val_U64_val_U64_val t6_Bool_val_Bool_val_u2_topology_StateChange_pony_CPPState_ref_ref_None_val_U64_val_U64_val_U64_val;

typedef struct ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_ref ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_ref;

typedef struct t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct t2_String_val_t2_String_val_String_val t2_String_val_t2_String_val_String_val;

typedef struct routing_$35$96_pony_CPPData_val routing_$35$96_pony_CPPData_val;

/*
A FilePath represents a capability to access a path. The path will be
represented as an absolute path and a set of capabilities for operations on
that path.
*/
typedef struct files_FilePath files_FilePath;

typedef struct u2_Array_U64_val_val_None_val u2_Array_U64_val_val_None_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref;

typedef struct recovery__RecoveryPhase recovery__RecoveryPhase;

typedef struct t2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val t2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val;

typedef struct topology_KeyedPartitionAddresses_U8_val topology_KeyedPartitionAddresses_U8_val;

typedef struct t2_U128_val_U128_val t2_U128_val_U128_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct network_$33$28 network_$33$28;

typedef struct fix_generator_utils_RandomNumberGenerator fix_generator_utils_RandomNumberGenerator;

typedef struct ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_val ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_box collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_box;

typedef struct u2_Array_topology_RunnerBuilder_val_val_None_val u2_Array_topology_RunnerBuilder_val_val_None_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections_HashEq_String_val_val collections_HashMap_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections_HashEq_String_val_val;

/*
An SSL context is used to create SSL sessions.
*/
typedef struct ssl_SSLContext ssl_SSLContext;

typedef struct files_FileStat files_FileStat;

typedef struct t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag;

typedef struct initialization_$15$72 initialization_$15$72;

typedef struct topology_EmptyRouter topology_EmptyRouter;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_box collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_box;

typedef struct ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_val ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_val;

typedef struct wallaroo_Pipeline_pony_CPPData_val_pony_CPPData_val wallaroo_Pipeline_pony_CPPData_val_pony_CPPData_val;

typedef struct routing_$35$74_pony_CPPData_val_topology_StateProcessor_pony_CPPState_ref_val routing_$35$74_pony_CPPData_val_topology_StateProcessor_pony_CPPState_ref_val;

typedef struct ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_box ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_box;

typedef struct data_channel_DataChannelConnectNotifier data_channel_DataChannelConnectNotifier;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_pony_CPPKey_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_pony_CPPKey_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_ref collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_ref;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_Any_tag_Any_tag_collections_HashIs_Any_tag_val collections_HashMap_Any_tag_Any_tag_collections_HashIs_Any_tag_val;

typedef struct collection_helpers_SetHelpers_String_val collection_helpers_SetHelpers_String_val;

typedef struct ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_ref ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_ref;

typedef struct network_$33$39 network_$33$39;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct ArrayValues_String_ref_Array_String_ref_box ArrayValues_String_ref_Array_String_ref_box;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct t2_String_val_I64_val t2_String_val_I64_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_topology_StateChange_pony_CPPState_ref_ref Array_topology_StateChange_pony_CPPState_ref_ref;

typedef struct messages1__GilesSendersStarted messages1__GilesSendersStarted;

typedef struct topology_StateChangeRepository_pony_CPPState_ref topology_StateChangeRepository_pony_CPPState_ref;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_val collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_val;

typedef struct Iterator_u2_String_val_Array_U8_val_val Iterator_u2_String_val_Array_U8_val_val;

typedef struct network_WallarooOutgoingNetworkActorNotify network_WallarooOutgoingNetworkActorNotify;

typedef struct u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_net_TCPListener_tag_net_TCPListener_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_net_TCPListener_tag_net_TCPListener_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_Initializable topology_Initializable;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_String_val Array_String_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_val collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_val;

typedef struct pony_CPPKey pony_CPPKey;

typedef struct t2_None_val_collections_ListNode_t2_Array_U8_val_val_USize_val_ref t2_None_val_collections_ListNode_t2_Array_U8_val_val_USize_val_ref;

typedef struct t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_iso_U64_val_U64_val_String_val_String_val t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_iso_U64_val_U64_val_String_val_String_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct recovery_$37$13 recovery_$37$13;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_box collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_box;

typedef struct wallaroo_Startup wallaroo_Startup;

typedef struct ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_box ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_box;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct t2_ISize_val_Bool_val t2_ISize_val_Bool_val;

typedef struct tcp_source_$40$10 tcp_source_$40$10;

typedef struct t2_u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val_u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val t2_u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val_u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_val collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_String_ref Array_String_ref;

typedef struct wallaroo_$19$28 wallaroo_$19$28;

typedef struct recovery_$37$26 recovery_$37$26;

/*
A set, built on top of a HashMap. This is implemented as map of an alias of
a type to itself
*/
typedef struct collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val;

/*
A set, built on top of a HashMap. This is implemented as map of an alias of
a type to itself
*/
typedef struct collections_HashSet_U128_val_collections_HashIs_U128_val_val collections_HashSet_U128_val_collections_HashIs_U128_val_val;

typedef struct u2_Array_String_val_val_topology_ProxyAddress_val u2_Array_String_val_val_topology_ProxyAddress_val;

typedef struct ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_ref ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_ref;

/*
This is a debug only assertion. If the test is false, it will print
'Invariant violated' along with the source file location of the
invariant to stderr and then forcibly exit the program.
*/
typedef struct invariant_Invariant invariant_Invariant;

typedef struct $0$13_String_val $0$13_String_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_val collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_val;

typedef struct ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_val ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_val;

typedef struct topology_$36$84_pony_CPPState_ref topology_$36$84_pony_CPPState_ref;

typedef struct routing_$35$74_pony_CPPData_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val routing_$35$74_pony_CPPData_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val;

typedef struct topology_$36$114_pony_CPPData_val_pony_CPPKey_val topology_$36$114_pony_CPPData_val_pony_CPPKey_val;

typedef struct ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_ref ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_ref;

typedef struct options_Required options_Required;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_box collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_box;

typedef struct u3_t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct boundary_$10$25 boundary_$10$25;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_box collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_box;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref;

typedef struct topology_AugmentablePartitionRouter_U8_val topology_AugmentablePartitionRouter_U8_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_val_U64_val_U64_val_String_val_String_val Array_t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_val_U64_val_U64_val_String_val_String_val;

typedef struct u2_topology_DirectRouter_val_None_val u2_topology_DirectRouter_val_None_val;

typedef struct u2_topology_Runner_iso_None_val u2_topology_Runner_iso_None_val;

typedef struct tcp_source_TCPSourceListenerBuilder tcp_source_TCPSourceListenerBuilder;

typedef struct t2_String_val_metrics__MetricsReporter_val t2_String_val_metrics__MetricsReporter_val;

typedef struct u2_boundary_DataReceiversSubscriber_tag_None_val u2_boundary_DataReceiversSubscriber_tag_None_val;

typedef struct recovery_$37$22 recovery_$37$22;

typedef struct u2_boundary_OutgoingBoundary_tag_None_val u2_boundary_OutgoingBoundary_tag_None_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u2_Array_U64_val_ref_None_val u2_Array_U64_val_ref_None_val;

typedef struct t3_Bool_val_Bool_val_U64_val t3_Bool_val_Bool_val_U64_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U128_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U128_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_net_TCPListener_tag_net_TCPListener_tag_collections_HashIs_net_TCPListener_tag_val collections_HashMap_net_TCPListener_tag_net_TCPListener_tag_collections_HashIs_net_TCPListener_tag_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_val collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_val;

typedef struct t2_time_Timer_tag_time_Timer_box t2_time_Timer_tag_time_Timer_box;

typedef struct boundary_OutgoingBoundary boundary_OutgoingBoundary;

typedef struct ArrayValues_U64_val_Array_U64_val_ref ArrayValues_U64_val_Array_U64_val_ref;

typedef struct u2_initialization_LocalTopology_val_None_val u2_initialization_LocalTopology_val_None_val;

typedef struct topology_$36$123_U64_val topology_$36$123_U64_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_box collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_box;

typedef struct topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_pony_CPPKey_val_pony_CPPState_ref topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_pony_CPPKey_val_pony_CPPState_ref;

typedef struct u3_t2_String_val_boundary_OutgoingBoundaryBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_boundary_OutgoingBoundaryBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u3_t2_time_Timer_tag_time_Timer_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_time_Timer_tag_time_Timer_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val;

typedef struct topology_StepBuilder topology_StepBuilder;

/*
ClusterManager

Interface for interacting with an external cluster manager to request a
new Wallaroo worker.
*/
typedef struct cluster_manager_ClusterManager cluster_manager_ClusterManager;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_ref collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_ref;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_box collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_box;

typedef struct hub_HubMsgTypes hub_HubMsgTypes;

typedef struct dag_Named dag_Named;

typedef struct collections_HashIs_tcp_source_TCPSourceListener_tag collections_HashIs_tcp_source_TCPSourceListener_tag;

typedef struct bytes_Bytes bytes_Bytes;

typedef struct ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_box ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_box;

typedef struct network_HomeConnectNotify network_HomeConnectNotify;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_Array_String_val_ref Array_Array_String_val_ref;

typedef struct topology_KeyedStateSubpartition_pony_CPPData_val_pony_CPPKey_val topology_KeyedStateSubpartition_pony_CPPData_val_pony_CPPKey_val;

typedef struct ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_box ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_box;

typedef struct topology_PartitionAddresses topology_PartitionAddresses;

typedef struct u2_wallaroo_InitFile_val_None_val u2_wallaroo_InitFile_val_None_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct topology_$36$100_pony_CPPData_val topology_$36$100_pony_CPPData_val;

typedef struct ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_ref ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_ref;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_options__Option_ref Array_options__Option_ref;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_pony_CPPKey_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_pony_CPPKey_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u2_options_Required_val_options_Optional_val u2_options_Required_val_options_Optional_val;

typedef struct t2_U128_val_topology_Step_tag t2_U128_val_topology_Step_tag;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct pony_$2$7 pony_$2$7;

typedef struct t2_routing_RouteLogic_val_routing_RouteLogic_val t2_routing_RouteLogic_val_routing_RouteLogic_val;

typedef struct recovery__ReplayPhase recovery__ReplayPhase;

typedef struct Equal Equal;

typedef struct metrics_NodeIngressEgressCategory metrics_NodeIngressEgressCategory;

typedef struct t2_topology_Initializable_tag_topology_Initializable_tag t2_topology_Initializable_tag_topology_Initializable_tag;

typedef struct routing_$35$97 routing_$35$97;

typedef struct ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_ref ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_ref;

typedef struct messages1_ExternalGilesSendersStartedMsg messages1_ExternalGilesSendersStartedMsg;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_t2_pony_CPPKey_val_USize_val Array_t2_pony_CPPKey_val_USize_val;

typedef struct tcp_source_FramedSourceNotify_pony_CPPData_val tcp_source_FramedSourceNotify_pony_CPPData_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_ref collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_ref;

typedef struct initialization_WorkerInitializer initialization_WorkerInitializer;

typedef struct messages_ForwardMsg_pony_CPPData_val messages_ForwardMsg_pony_CPPData_val;

typedef struct u2_routing_BoundaryRoute_ref_routing_TypedRoute_topology_StateProcessor_pony_CPPState_ref_val_ref u2_routing_BoundaryRoute_ref_routing_TypedRoute_topology_StateProcessor_pony_CPPState_ref_val_ref;

typedef struct topology_$36$98 topology_$36$98;

typedef struct u2_topology_StateChange_pony_CPPState_ref_ref_None_val u2_topology_StateChange_pony_CPPState_ref_ref_None_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_box collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_box;

typedef struct None None;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections_HashEq_String_val_val collections_HashMap_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections_HashEq_String_val_val;

typedef struct network_$33$27 network_$33$27;

typedef struct u3_t2_U64_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U64_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U64_val_Bool_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U64_val_Bool_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct t2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_trn_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_trn t2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_trn_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_trn;

typedef struct u2_i2_recovery_Resilient_tag_routing_Producer_tag_None_val u2_i2_recovery_Resilient_tag_routing_Producer_tag_None_val;

typedef struct topology_$36$126 topology_$36$126;

typedef struct t2_u2_String_val_Array_U8_val_val_USize_val t2_u2_String_val_Array_U8_val_val_USize_val;

/*
This type represents the root capability. When a Pony program starts, the
Env passed to the Main actor contains an instance of the root capability.

Ambient access to the root capability is denied outside of the builtin
package. Inside the builtin package, only Env creates a Root.

The root capability can be used by any package that wants to establish a
principle of least authority. A typical usage is to have a parameter on a
constructor for some resource that expects a limiting capability specific to
the package, but will also accept the root capability as representing
unlimited access.
*/
typedef struct AmbientAuth AmbientAuth;

typedef struct topology_Partition_pony_CPPData_val_pony_CPPKey_val topology_Partition_pony_CPPData_val_pony_CPPKey_val;

typedef struct t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val;

typedef struct ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_ref ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_ref;

typedef struct routing_TypedRouteBuilder_pony_CPPData_val routing_TypedRouteBuilder_pony_CPPData_val;

typedef struct boundary_$10$11 boundary_$10$11;

typedef struct u3_t2_U64_val_Bool_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U64_val_Bool_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
Operations on a file.
*/
typedef struct files_File files_File;

/*
Notification for data arriving via stdin.
*/
typedef struct StdinNotify StdinNotify;

typedef struct t2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val t2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_val collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_val;

typedef struct ArrayValues_options__Option_ref_Array_options__Option_ref_ref ArrayValues_options__Option_ref_Array_options__Option_ref_ref;

typedef struct t2_U8_val_USize_val t2_U8_val_USize_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_box collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_box;

typedef struct u2_pony_CPPData_iso_None_val u2_pony_CPPData_iso_None_val;

typedef struct collections_HashIs_topology_Step_tag collections_HashIs_topology_Step_tag;

typedef struct u2_U64_val_None_val u2_U64_val_None_val;

typedef struct ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_ref ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_ref;

typedef struct u2_topology_PartitionRouter_val_None_val u2_topology_PartitionRouter_val_None_val;

typedef struct u4_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val_net_TCPListenAuth_val u4_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val_net_TCPListenAuth_val;

typedef struct ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_val ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_val;

/*
Iterate over the values in a list.
*/
typedef struct collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_ref collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_ref;

typedef struct files_FileRename files_FileRename;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_box collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_box;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_ref collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_ref;

typedef struct u2_String_val_Array_U8_val_val u2_String_val_Array_U8_val_val;

typedef struct boundary__UninitializedTimerInit boundary__UninitializedTimerInit;

typedef struct t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_val t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_val;

typedef struct boundary_DataReceiver boundary_DataReceiver;

typedef struct files_FileChown files_FileChown;

typedef struct initialization_$15$61 initialization_$15$61;

typedef struct collections_HashEq_boundary__BoundaryId_ref collections_HashEq_boundary__BoundaryId_ref;

typedef struct messages_DeliveryMsg messages_DeliveryMsg;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u2_routing_BoundaryRoute_ref_routing_TypedRoute_pony_CPPData_val_ref u2_routing_BoundaryRoute_ref_routing_TypedRoute_pony_CPPData_val_ref;

typedef struct messages_DataConnectMsg messages_DataConnectMsg;

typedef struct ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_ref ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_ref;

typedef struct recovery_$37$30_String_val_U128_val recovery_$37$30_String_val_U128_val;

typedef struct ArrayValues_String_val_Array_String_val_box ArrayValues_String_val_Array_String_val_box;

typedef struct ArrayValues_U64_val_Array_U64_val_box ArrayValues_U64_val_Array_U64_val_box;

typedef struct topology_$36$102_pony_CPPData_val topology_$36$102_pony_CPPData_val;

typedef struct t2_String_val_topology_Router_val t2_String_val_topology_Router_val;

typedef struct t2_None_val_collections_ListNode_time_Timer_ref_ref t2_None_val_collections_ListNode_time_Timer_ref_ref;

typedef struct ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_box ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_box;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections_HashIs_data_channel_DataChannel_tag_val collections_HashMap_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections_HashIs_data_channel_DataChannel_tag_val;

typedef struct messages_StartNormalDataSendingMsg messages_StartNormalDataSendingMsg;

/*
A hierarchical set of timing wheels.
*/
typedef struct time_Timers time_Timers;

typedef struct u2_t2_Array_U8_val_val_USize_val_None_val u2_t2_Array_U8_val_val_USize_val_None_val;

typedef struct routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_topology_StateProcessor_pony_CPPState_ref_val routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_topology_StateProcessor_pony_CPPState_ref_val;

typedef struct metrics_MetricsSinkNotify metrics_MetricsSinkNotify;

typedef struct ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_val ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_val;

typedef struct t2_ISize_val_ISize_val t2_ISize_val_ISize_val;

/*
A node in a list.
*/
typedef struct collections_ListNode_http_Payload_val collections_ListNode_http_Payload_val;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_ref collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_ref;

typedef struct ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_box ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_box;

typedef struct u2_files_FilePath_val_AmbientAuth_val u2_files_FilePath_val_AmbientAuth_val;

typedef struct u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val;

/*
A node in a list.
*/
typedef struct collections_ListNode_t2_USize_val_U64_val collections_ListNode_t2_USize_val_U64_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref;

typedef struct t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag;

typedef struct topology_$36$122_pony_CPPKey_val topology_$36$122_pony_CPPKey_val;

typedef struct u2_recovery_FileBackend_ref_recovery_DummyBackend_ref u2_recovery_FileBackend_ref_recovery_DummyBackend_ref;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_ref collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_ref;

typedef struct u3_t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_PreStateRunner_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref topology_PreStateRunner_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref;

typedef struct t2_U64_val_t3_routing_Producer_tag_U64_val_U64_val t2_U64_val_t3_routing_Producer_tag_U64_val_U64_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u2_String_box_Array_U8_val_box u2_String_box_Array_U8_val_box;

/*
A set, built on top of a HashMap. This is implemented as map of an alias of
a type to itself
*/
typedef struct collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val;

typedef struct t2_U64_val_U128_val t2_U64_val_U128_val;

typedef struct messages_KeyedStepMigrationMsg_U8_val messages_KeyedStepMigrationMsg_U8_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct messages_IdentifyDataPortMsg messages_IdentifyDataPortMsg;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val;

/*
A set, built on top of a HashMap. This is implemented as map of an alias of
a type to itself
*/
typedef struct collections_HashSet_data_channel_DataChannel_tag_collections_HashIs_data_channel_DataChannel_tag_val collections_HashSet_data_channel_DataChannel_tag_collections_HashIs_data_channel_DataChannel_tag_val;

typedef struct messages1_ExternalDataMsg messages1_ExternalDataMsg;

typedef struct t2_U64_val_routing__Route_box t2_U64_val_routing__Route_box;

/*
A set, built on top of a HashMap. This is implemented as map of an alias of
a type to itself
*/
typedef struct collections_HashSet_String_val_collections_HashIs_String_val_val collections_HashSet_String_val_collections_HashIs_String_val_val;

typedef struct ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_ref ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_ref;

typedef struct t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_box t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_box;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct weighted_Weighted_pony_CPPKey_val weighted_Weighted_pony_CPPKey_val;

typedef struct pony_CPPSourceDecoder pony_CPPSourceDecoder;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections_HashEq_String_val_val collections_HashMap_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections_HashEq_String_val_val;

typedef struct collections_HashEq_http__HostService_val collections_HashEq_http__HostService_val;

typedef struct messages1__Shutdown messages1__Shutdown;

typedef struct ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_box ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_box;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_t2_U8_val_USize_val Array_t2_U8_val_USize_val;

typedef struct topology_$36$99_pony_CPPData_val topology_$36$99_pony_CPPData_val;

typedef struct u3_t2_U64_val_routing__Route_ref_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U64_val_routing__Route_ref_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An HTTP payload. For a response, the method indicates the status text. For a
request, the status is meaningless.
*/
typedef struct http_Payload http_Payload;

typedef struct ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_val ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_val;

/*
Holds the components of a URL. These are always stored as valid, URL-encoded
values.
*/
typedef struct http_URL http_URL;

typedef struct messages1_ExternalStartMsg messages1_ExternalStartMsg;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct boundary__DataReceiverAcceptingReplaysPhase boundary__DataReceiverAcceptingReplaysPhase;

typedef struct u6_http_URLPartUser_val_http_URLPartPassword_val_http_URLPartHost_val_http_URLPartPath_val_http_URLPartQuery_val_http_URLPartFragment_val u6_http_URLPartUser_val_http_URLPartPassword_val_http_URLPartHost_val_http_URLPartPath_val_http_URLPartQuery_val_http_URLPartFragment_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_val ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U64_val_routing__Route_ref_collections_HashEq_U64_val_val collections_HashMap_U64_val_routing__Route_ref_collections_HashEq_U64_val_val;

typedef struct ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_ref ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_ref;

typedef struct topology_PreStateData topology_PreStateData;

typedef struct ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_val ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_val;

typedef struct u2_routing_RouteLogic_ref_None_val u2_routing_RouteLogic_ref_None_val;

typedef struct u2_topology_ProxyRouter_val_topology_DirectRouter_val u2_topology_ProxyRouter_val_topology_DirectRouter_val;

typedef struct u3_t2_U128_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U128_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_ref ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_ref;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val;

/*
# TCPSource

## Future work
* Switch to requesting credits via promise
*/
typedef struct tcp_source_TCPSource tcp_source_TCPSource;

typedef struct topology_$36$124_U64_val topology_$36$124_U64_val;

typedef struct $0$1_U32_val $0$1_U32_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_val collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_val;

typedef struct t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag;

typedef struct boundary_$10$17_pony_CPPData_val boundary_$10$17_pony_CPPData_val;

typedef struct topology_$36$133 topology_$36$133;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_ref collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_ref;

typedef struct recovery_$37$23 recovery_$37$23;

typedef struct files_FileTruncate files_FileTruncate;

typedef struct topology_PauseBeforeMigrationNotify topology_PauseBeforeMigrationNotify;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_ref collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_ref;

/*
A trait for sending messages to workers in the cluster.
*/
typedef struct network_Cluster network_Cluster;

typedef struct Greater Greater;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val;

typedef struct metrics_StartToEndCategory metrics_StartToEndCategory;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_box collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_box;

typedef struct tcp_source_SourceListenerNotify tcp_source_SourceListenerNotify;

typedef struct recovery_$37$25 recovery_$37$25;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref;

/*
Represents a location in a Pony source file, as reported by `__loc`.
*/
typedef struct SourceLoc SourceLoc;

typedef struct u2_tcp_source_TCPSource_tag_None_val u2_tcp_source_TCPSource_tag_None_val;

/*
A set, built on top of a HashMap. This is implemented as map of an alias of
a type to itself
*/
typedef struct collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val;

typedef struct u2_tcp_sink_TCPSink_tag_tcp_sink_EmptySink_tag u2_tcp_sink_TCPSink_tag_tcp_sink_EmptySink_tag;

typedef struct recovery__Replay recovery__Replay;

typedef struct tcp_source_FramedSourceHandler_pony_CPPData_val tcp_source_FramedSourceHandler_pony_CPPData_val;

typedef struct topology_EmptyOmniRouter topology_EmptyOmniRouter;

typedef struct t2_pony_CPPKey_val_USize_val t2_pony_CPPKey_val_USize_val;

typedef struct topology_ProxyRouter topology_ProxyRouter;

typedef struct u2_t2_U128_val_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_None_val u2_t2_U128_val_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_None_val;

typedef struct topology_StateChangeBuilder_pony_CPPState_ref topology_StateChangeBuilder_pony_CPPState_ref;

/*
This only exists for testability.
*/
typedef struct recovery__RecoveryReplayer recovery__RecoveryReplayer;

typedef struct collection_helpers_$39$0_String_val collection_helpers_$39$0_String_val;

typedef struct u2_USize_val_None_val u2_USize_val_None_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U128_val_U128_val_collections_HashIs_U128_val_val collections_HashMap_U128_val_U128_val_collections_HashIs_U128_val_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_Array_pony_CPPKey_val_ref Array_Array_pony_CPPKey_val_ref;

typedef struct u2_options__Option_ref_None_val u2_options__Option_ref_None_val;

typedef struct u2_Array_t2_U64_val_USize_val_val_Array_U64_val_val u2_Array_t2_U64_val_USize_val_val_Array_U64_val_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_t2_U64_val_t3_routing_Producer_tag_U64_val_U64_val Array_t2_U64_val_t3_routing_Producer_tag_U64_val_U64_val;

typedef struct network_ControlSenderConnectNotifier network_ControlSenderConnectNotifier;

typedef struct messages_ConnectionsReadyMsg messages_ConnectionsReadyMsg;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_topology_RunnerBuilder_val Array_topology_RunnerBuilder_val;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_box collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_box;

typedef struct recovery_$37$21 recovery_$37$21;

typedef struct initialization_ApplicationInitializer initialization_ApplicationInitializer;

typedef struct recovery_$37$9 recovery_$37$9;

typedef struct u3_t2_U128_val_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U128_val_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct topology_$36$85_pony_CPPState_ref topology_$36$85_pony_CPPState_ref;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct topology_$36$112_pony_CPPData_val_pony_CPPKey_val topology_$36$112_pony_CPPData_val_pony_CPPKey_val;

typedef struct topology_$36$124_pony_CPPKey_val topology_$36$124_pony_CPPKey_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_time_Timer_tag_time_Timer_ref_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_time_Timer_tag_time_Timer_ref_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U8_val_topology_ProxyAddress_val_collections_HashEq_U8_val_val collections_HashMap_U8_val_topology_ProxyAddress_val_collections_HashEq_U8_val_val;

typedef struct u2_recovery_EventLog_tag_None_val u2_recovery_EventLog_tag_None_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val;

typedef struct weighted_Weighted_U64_val weighted_Weighted_U64_val;

/*
A doubly linked list.
*/
typedef struct collections_List_http_Payload_val collections_List_http_Payload_val;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_val collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_val;

typedef struct u3_t2_String_val_metrics__MetricsReporter_box_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_metrics__MetricsReporter_box_collections__MapEmpty_val_collections__MapDeleted_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U128_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U128_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_pony_CPPKey_val_topology_ProxyAddress_val_collections_HashEq_pony_CPPKey_val_val collections_HashMap_pony_CPPKey_val_topology_ProxyAddress_val_collections_HashEq_pony_CPPKey_val_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box;

typedef struct u3_t2_topology_Initializable_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_topology_Initializable_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u2_AmbientAuth_val_None_val u2_AmbientAuth_val_None_val;

typedef struct Main Main;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val;

typedef struct ArrayValues_String_val_Array_String_val_tag ArrayValues_String_val_Array_String_val_tag;

typedef struct collections_HashIs_data_channel_DataChannel_tag collections_HashIs_data_channel_DataChannel_tag;

typedef struct t2_I64_val_USize_val t2_I64_val_USize_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val;

/*
Implementation of dual-pivot quicksort.
*/
typedef struct collections_Sort_Array_U128_val_ref_U128_val collections_Sort_Array_U128_val_ref_U128_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_box collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_box;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box;

typedef struct boundary_$10$19 boundary_$10$19;

typedef struct u2_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_None_val u2_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_None_val;

typedef struct ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_box ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_box;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_box collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_box;

typedef struct u3_t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u2_collections_ListNode_t2_USize_val_U64_val_ref_None_val u2_collections_ListNode_t2_USize_val_U64_val_ref_None_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val;

typedef struct t2_U64_val_routing__Route_val t2_U64_val_routing__Route_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val;

typedef struct topology_$36$113_pony_CPPData_val_U8_val topology_$36$113_pony_CPPData_val_U8_val;

typedef struct collections_HashIs_data_channel_DataChannelListener_tag collections_HashIs_data_channel_DataChannelListener_tag;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections_HashEq_String_val_val collections_HashMap_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections_HashEq_String_val_val;

typedef struct initialization_$15$68 initialization_$15$68;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_ref collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_ref;

typedef struct u2_net_TCPListener_tag_None_val u2_net_TCPListener_tag_None_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref;

typedef struct initialization_$15$75 initialization_$15$75;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U128_val_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U128_val_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct boundary_$10$24 boundary_$10$24;

typedef struct u3_t2_String_val_topology_PartitionRouter_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_topology_PartitionRouter_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct recovery__WaitForReconnections recovery__WaitForReconnections;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
The `Random` trait should be implemented by all random number generators. The
only method you need to implement is `fun ref next(): 64`. Once that method
has been implemented, the `Random` trait provides default implementations of
conversions to other number types.
*/
typedef struct random_Random random_Random;

typedef struct topology_ComputationRunner_pony_CPPData_val_pony_CPPData_val topology_ComputationRunner_pony_CPPData_val_pony_CPPData_val;

typedef struct t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref;

typedef struct u2_collections_ListNode_time_Timer_ref_ref_None_val u2_collections_ListNode_time_Timer_ref_ref_None_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u2_collections_List_t2_Array_U8_val_val_USize_val_ref_None_val u2_collections_List_t2_Array_U8_val_val_USize_val_ref_None_val;

typedef struct $0$13_routing_Producer_tag $0$13_routing_Producer_tag;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct data_channel__DataReceiver data_channel__DataReceiver;

typedef struct network_$33$24_pony_CPPKey_val network_$33$24_pony_CPPKey_val;

typedef struct weighted_Weighted_U8_val weighted_Weighted_U8_val;

typedef struct ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_box ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_box;

typedef struct files_FileChmod files_FileChmod;

typedef struct tcp_source_SourceBuilderBuilder tcp_source_SourceBuilderBuilder;

typedef struct wallaroo_BasicPipeline wallaroo_BasicPipeline;

typedef struct files_FileTime files_FileTime;

typedef struct metrics_ComputationCategory metrics_ComputationCategory;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_ref collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_ref;

typedef struct t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_val collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u2_None_val_wallaroo_PipelineBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_ref u2_None_val_wallaroo_PipelineBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_ref;

typedef struct collections_HashEq_U8_val collections_HashEq_U8_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_box collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_box;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_val collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_val collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_val collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_val;

/*
This is a capability token that allows the holder to treat data arbitrary
bytes as serialised data. This is the most dangerous capability, as currently
it is possible for a malformed chunk of data to crash your program if it is
deserialised.
*/
typedef struct serialise_InputSerialisedAuth serialise_InputSerialisedAuth;

typedef struct files_FileLink files_FileLink;

typedef struct u2_recovery_Recovery_tag_None_val u2_recovery_Recovery_tag_None_val;

typedef struct u2_collections_ListNode_time_Timer_ref_box_None_val u2_collections_ListNode_time_Timer_ref_box_None_val;

typedef struct messages_StepMigrationCompleteMsg messages_StepMigrationCompleteMsg;

typedef struct network_ControlChannelListenNotifier network_ControlChannelListenNotifier;

typedef struct data_channel_DataChannelListenNotifier data_channel_DataChannelListenNotifier;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_ref collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_ref;

typedef struct boundary_$10$18_topology_StateProcessor_pony_CPPState_ref_val boundary_$10$18_topology_StateProcessor_pony_CPPState_ref_val;

typedef struct topology_StateChange_pony_CPPState_ref topology_StateChange_pony_CPPState_ref;

typedef struct t2_u2_String_val_None_val_Bool_val t2_u2_String_val_None_val_Bool_val;

typedef struct http_URLPartQuery http_URLPartQuery;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U8_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U8_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u3_t2_U64_val_routing__Route_box_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U64_val_routing__Route_box_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct recovery__WaitingForBoundaryCounts recovery__WaitingForBoundaryCounts;

typedef struct u3_t2_routing_RouteLogic_ref_routing_RouteLogic_ref_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_routing_RouteLogic_ref_routing_RouteLogic_ref_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U64_val_topology_ProxyAddress_val_collections_HashEq_U64_val_val collections_HashMap_U64_val_topology_ProxyAddress_val_collections_HashEq_U64_val_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u2_t2_USize_val_U64_val_None_val u2_t2_USize_val_U64_val_None_val;

typedef struct data_channel_$45$8 data_channel_$45$8;

typedef struct u3_String_val_Array_String_val_val_None_val u3_String_val_Array_String_val_val_None_val;

typedef struct files_FileRemove files_FileRemove;

typedef struct topology_DefaultStateable topology_DefaultStateable;

typedef struct topology_PartitionRouter topology_PartitionRouter;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct files_FileLookup files_FileLookup;

typedef struct t2_U8_val_U128_val t2_U8_val_U128_val;

typedef struct ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_ref ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_ref;

typedef struct u3_Array_String_val_val_String_val_None_val u3_Array_String_val_val_String_val_None_val;

typedef struct u2_time_Timer_ref_None_val u2_time_Timer_ref_None_val;

typedef struct u2_data_channel_DataChannel_tag_None_val u2_data_channel_DataChannel_tag_None_val;

typedef struct topology_$36$86_pony_CPPState_ref topology_$36$86_pony_CPPState_ref;

typedef struct recovery_$37$27 recovery_$37$27;

typedef struct files_FileOK files_FileOK;

typedef struct AsioEventNotify AsioEventNotify;

typedef struct u3_t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u2_None_val_String_val u2_None_val_String_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_ref collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_ref;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_routing_RouteLogic_ref_routing_RouteLogic_ref_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_routing_RouteLogic_ref_routing_RouteLogic_ref_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_$36$106 topology_$36$106;

typedef struct u3_t2_routing_Consumer_tag_routing_Route_ref_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_routing_Consumer_tag_routing_Route_ref_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u2_tcp_source_TCPSourceListener_tag_None_val u2_tcp_source_TCPSourceListener_tag_None_val;

typedef struct collections_HashEq_U64_val collections_HashEq_U64_val;

typedef struct pony_CPPComputation pony_CPPComputation;

typedef struct messages1__StartGilesSenders messages1__StartGilesSenders;

typedef struct collections_HashEq_U128_val collections_HashEq_U128_val;

typedef struct u2_initialization_ApplicationInitializer_tag_None_val u2_initialization_ApplicationInitializer_tag_None_val;

typedef struct dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val;

/*
All the routes available
*/
typedef struct routing_Routes routing_Routes;

typedef struct t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_$36$116 topology_$36$116;

typedef struct t2_None_val_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref t2_None_val_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref;

typedef struct t2_routing_RouteLogic_ref_routing_RouteLogic_ref t2_routing_RouteLogic_ref_routing_RouteLogic_ref;

/*
A doubly linked list.
*/
typedef struct collections_List_t2_USize_val_U64_val collections_List_t2_USize_val_U64_val;

typedef struct u2_initialization_WorkerInitializer_tag_None_val u2_initialization_WorkerInitializer_tag_None_val;

typedef struct t2_u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val_u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val t2_u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val_u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val;

typedef struct messages_MigrationBatchCompleteMsg messages_MigrationBatchCompleteMsg;

/*
A TCP connection. When connecting, the Happy Eyeballs algorithm is used.

The following code creates a client that connects to port 8989 of
the local host, writes "hello world", and listens for a response,
which it then prints.

```
use "net"

class MyTCPConnectionNotify is TCPConnectionNotify
  let _out: OutStream

  new create(out: OutStream) =>
    _out = out

  fun ref connected(conn: TCPConnection ref) =>
    conn.write("hello world")

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    _out.print("GOT:" + String.from_array(consume data))
    conn.close()

actor Main
  new create(env: Env) =>
    try
      TCPConnection(env.root as AmbientAuth,
        recover MyTCPConnectionNotify(env.out) end, "", "8989")
    end
```

## Backpressure support

### Write

The TCP protocol has built-in backpressure support. This is generally
experienced as the outgoing write buffer becoming full and being unable
to write all requested data to the socket. In `TCPConnection`, this is
hidden from the programmer. When this occurs, `TCPConnection` will buffer
the extra data until such time as it is able to be sent. Left unchecked,
this could result in uncontrolled queuing. To address this,
`TCPConnectionNotify` implements two methods `throttled` and `unthrottled`
that are called when backpressure is applied and released.

Upon receiving a `throttled` notification, your application has two choices
on how to handle it. One is to inform any actors sending the connection to
stop sending data. For example, you might construct your application like:

```pony
// Here we have a TCPConnectionNotify that upon construction
// is given a tag to a "Coordinator". Any actors that want to
// "publish" to this connection should register with the
// coordinator. This allows the notifier to inform the coordinator
// that backpressure has been applied and then it in turn can
// notify senders who could then pause sending.

class SlowDown is TCPConnectionNotify
  let _coordinator: Coordinator

  new create(coordinator: Coordinator) =>
    _coordinator = coordinator

  fun ref throttled(connection: TCPConnection ref) =>
    _coordinator.throttled(this)

  fun ref unthrottled(connection: TCPConnection ref) =>
    _coordinator.unthrottled(this)

actor Coordinator
  var _senders: List[Any tag] = _senders.create()

  be register(sender: Any tag) =>
    _senders.push(sender)

  be throttled(connection: TCPConnection) =>
    for sender in _senders.values() do
      sender.pause_sending_to(connection)
    end

   be unthrottled(connection: TCPConnection) =>
    for sender in _senders.values() do
      sender.resume_sending_to(connection)
    end
```

Or if you want, you could handle backpressure by shedding load, that is,
dropping the extra data rather than carrying out the send. This might look
like:

```pony
class ThrowItAway is TCPConnectionNotify
  var _throttled = false

  fun ref sent(conn: TCPConnection ref, data: ByteSeq): ByteSeq =>
    if not _throttled then
      data
    else
      ""
    end

fun ref sentv(conn: TCPConnection ref, data: ByteSeqIter): ByteSeqIter =>
  if not _throttled then
    data
  else
    Array[String]
  end

  fun ref throttled(connection: TCPConnection ref) =>
    _throttled = true

  fun ref unthrottled(connection: TCPConnection ref) =>
    _throttled = false
```

In general, unless you have a very specific use case, we strongly advise that
you don't implement a load shedding scheme where you drop data.

### Read

If your application is unable to keep up with data being sent to it over
a `TCPConnection` you can use the builtin read backpressure support to
pause reading the socket which will in turn start to exert backpressure on
the corresponding writer on the other end of that socket.

The `mute` behavior allow any other actors in your application to request
the cessation of additional reads until such time as `unmute` is called.
Please note that this cessation is not guaranteed to happen immediately as
it is the result of an asynchronous behavior call and as such will have to
wait for existing messages in the `TCPConnection`'s mailbox to be handled.

On non-windows platforms, your `TCPConnection` will not notice if the
other end of the connection closes until you unmute it. Unix type systems
like FreeBSD, Linux and OSX learn about a closed connection upon read. On
these platforms, you **must** call `unmute` on a muted connection to have
it close. Without calling `unmute` the `TCPConnection` actor will never
exit.
*/
typedef struct net_TCPConnection net_TCPConnection;

typedef struct topology_LocalPartitionRouter_pony_CPPData_val_U8_val topology_LocalPartitionRouter_pony_CPPData_val_U8_val;

typedef struct u3_t2_routing_Consumer_tag_routing_Route_box_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_routing_Consumer_tag_routing_Route_box_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_$36$112_pony_CPPData_val_U64_val topology_$36$112_pony_CPPData_val_U64_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u2_topology_ProxyAddress_val_None_val u2_topology_ProxyAddress_val_None_val;

typedef struct topology_LocalPartitionRouter_pony_CPPData_val_U64_val topology_LocalPartitionRouter_pony_CPPData_val_U64_val;

typedef struct t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_val_U64_val_U64_val_String_val_String_val t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_val_U64_val_U64_val_String_val_String_val;

typedef struct u3_t2_boundary__BoundaryId_box_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_boundary__BoundaryId_box_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct metrics_DefaultMetricsMonitor metrics_DefaultMetricsMonitor;

typedef struct t2_U128_val_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val t2_U128_val_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val;

typedef struct topology_KeyedStateSubpartition_pony_CPPData_val_U8_val topology_KeyedStateSubpartition_pony_CPPData_val_U8_val;

/*
Notifications for TCP connections.

For an example of using this class please see the documentation for the
`TCPConnection` and `TCPListener` actors.
*/
typedef struct net_TCPConnectionNotify net_TCPConnectionNotify;

typedef struct u3_t2_String_val_metrics__MetricsReporter_ref_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_metrics__MetricsReporter_ref_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct recovery_CheckCounts_String_val_U128_val recovery_CheckCounts_String_val_U128_val;

typedef struct topology_StateProcessor_pony_CPPState_ref topology_StateProcessor_pony_CPPState_ref;

typedef struct routing_RouteBuilder routing_RouteBuilder;

typedef struct tcp_sink_TCPSinkBuilder tcp_sink_TCPSinkBuilder;

typedef struct t2_net_TCPListener_tag_net_TCPListener_tag t2_net_TCPListener_tag_net_TCPListener_tag;

typedef struct messages_ReplayCompleteMsg messages_ReplayCompleteMsg;

typedef struct messages1__Data messages1__Data;

typedef struct u3_t2_String_val_topology_StateSubpartition_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_topology_StateSubpartition_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct t5_topology_Step_ref_U128_val_None_val_U64_val_U64_val t5_topology_Step_ref_U128_val_None_val_U64_val_U64_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_http__HostService_val_http__ClientConnection_tag_collections_HashEq_http__HostService_val_val collections_HashMap_http__HostService_val_http__ClientConnection_tag_collections_HashEq_http__HostService_val_val;

typedef struct network_$33$37 network_$33$37;

typedef struct t3_U8_val_U128_val_topology_Step_tag t3_U8_val_U128_val_topology_Step_tag;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_ref collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_ref;

/*
Functions for checking, encoding, and decoding parts of URLs.
*/
typedef struct http_URLEncode http_URLEncode;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_ref collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_ref;

typedef struct Iterator_u2_String_box_Array_U8_val_box Iterator_u2_String_box_Array_U8_val_box;

typedef struct t2_U64_val_USize_val t2_U64_val_USize_val;

typedef struct options__ErrorPrinter options__ErrorPrinter;

typedef struct collections_HashIs_tcp_source_TCPSource_tag collections_HashIs_tcp_source_TCPSource_tag;

/*
Notifications for timer.
*/
typedef struct time_TimerNotify time_TimerNotify;

typedef struct t2_U128_val_String_val t2_U128_val_String_val;

typedef struct tcp_source_$40$9_pony_CPPData_val tcp_source_$40$9_pony_CPPData_val;

typedef struct ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_val ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_val;

typedef struct messages_RequestBoundaryCountMsg messages_RequestBoundaryCountMsg;

typedef struct routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_topology_StateProcessor_pony_CPPState_ref_val routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_topology_StateProcessor_pony_CPPState_ref_val;

typedef struct http_URLPartUser http_URLPartUser;

typedef struct topology_AugmentablePartitionRouter_pony_CPPKey_val topology_AugmentablePartitionRouter_pony_CPPKey_val;

/*
The `Timer` class represents a timer that fires after an expiration
time, and then fires at an interval. When a `Timer` fires, it calls
the `apply` method of the `TimerNotify` object that was passed to it
when it was created.

The following example waits 5 seconds and then fires every 2
seconds, and when it fires the `TimerNotify` object prints how many
times it has been called:

```
use "time"

actor Main
  new create(env: Env) =>
    let timers = Timers
    let timer = Timer(Notify(env), 5_000_000_000, 2_000_000_000)
    timers(consume timer)

class Notify is TimerNotify
  let _env: Env
  var _counter: U32 = 0
  new iso create(env: Env) =>
    _env = env
  fun ref apply(timer: Timer, count: U64): Bool =>
    _env.out.print(_counter.string())
    _counter = _counter + 1
    true
```
*/
typedef struct time_Timer time_Timer;

typedef struct boundary__DataReceiverProcessingPhase boundary__DataReceiverProcessingPhase;

typedef struct net_TCPConnectAuth net_TCPConnectAuth;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_topology_PartitionBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_topology_PartitionBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct initialization_$15$66 initialization_$15$66;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_val collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_val;

typedef struct initialization_$15$74 initialization_$15$74;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_t2_U64_val_USize_val Array_t2_U64_val_USize_val;

typedef struct u2_topology_ProxyAddress_val_U128_val u2_topology_ProxyAddress_val_U128_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U128_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U128_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct t3_routing_Producer_tag_U64_val_U64_val t3_routing_Producer_tag_U64_val_U64_val;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_val collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_val;

typedef struct t2_time_Timer_tag_time_Timer_val t2_time_Timer_tag_time_Timer_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U128_val_u2_topology_ProxyAddress_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U128_val_u2_topology_ProxyAddress_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box;

typedef struct topology_$36$123_U8_val topology_$36$123_U8_val;

typedef struct ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_box ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_box;

typedef struct messages_DataMsg messages_DataMsg;

typedef struct t2_u2_collections_ListNode_time_Timer_ref_ref_None_val_u2_collections_ListNode_time_Timer_ref_ref_None_val t2_u2_collections_ListNode_time_Timer_ref_ref_None_val_u2_collections_ListNode_time_Timer_ref_ref_None_val;

typedef struct options_Optional options_Optional;

typedef struct routing_$35$74_pony_CPPData_val_pony_CPPData_val routing_$35$74_pony_CPPData_val_pony_CPPData_val;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_box collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_box;

/*
This message is sent as a response to a JoinCluster message. Currently it
only informs the new worker of metrics-related info
*/
typedef struct messages_InformJoiningWorkerMsg messages_InformJoiningWorkerMsg;

typedef struct topology_$36$131 topology_$36$131;

typedef struct boundary_$10$13 boundary_$10$13;

typedef struct topology_PartitionFunction_pony_CPPData_val_U8_val topology_PartitionFunction_pony_CPPData_val_U8_val;

typedef struct network_$33$40 network_$33$40;

typedef struct u2_metrics__MetricsReporter_ref_None_val u2_metrics__MetricsReporter_ref_None_val;

typedef struct routing__RouteLogic routing__RouteLogic;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_ref collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_ref;

typedef struct wallaroo_Application wallaroo_Application;

/*
This is a capability token that allows the holder to examine serialised data.
This should only be provided to types that need to write serialised data to
some output stream, such as a file or socket. A type with the SerialiseAuth
capability should usually not also have OutputSerialisedAuth, as the
combination gives the holder the ability to examine the bitwise contents of
any object it has a reference to.
*/
typedef struct serialise_OutputSerialisedAuth serialise_OutputSerialisedAuth;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box;

typedef struct pony_CPPPartitionFunction pony_CPPPartitionFunction;

typedef struct pony_CPPStateBuilder pony_CPPStateBuilder;

typedef struct topology_$36$125_U8_val topology_$36$125_U8_val;

typedef struct u3_t2_String_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_ref collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_ref;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U128_val_topology_Router_val_collections_HashEq_U128_val_val collections_HashMap_U128_val_topology_Router_val_collections_HashEq_U128_val_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_ref ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_ref;

typedef struct routing_$35$75_pony_CPPData_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val routing_$35$75_pony_CPPData_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val;

typedef struct topology_RunnerSequenceBuilder topology_RunnerSequenceBuilder;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val;

typedef struct u3_t2_pony_CPPKey_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_pony_CPPKey_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct network_$33$21 network_$33$21;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct t2_String_val_String_val t2_String_val_String_val;

typedef struct boundary_$10$14 boundary_$10$14;

typedef struct collections_HashIs_Any_tag collections_HashIs_Any_tag;

typedef struct ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_box ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_box;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_val ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_val;

typedef struct messages1__Ready messages1__Ready;

typedef struct t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val;

typedef struct ArrayValues_U8_val_Array_U8_val_box ArrayValues_U8_val_Array_U8_val_box;

typedef struct t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val;

/*
Notifications for TCPSource listeners.
*/
typedef struct tcp_source_TCPSourceListenerNotify tcp_source_TCPSourceListenerNotify;

/*
DockerSwarmServicesResponseHandler

Provides a response handler for our Payload which is then used to notify
our DockerSwarmClusterManager to generate_new_worker_request() if a proper
  service response is received from our services GET request.

TODO: This will need to be replaced when new HTTP package is pulled in from
latest ponyc.
*/
typedef struct cluster_manager_DockerSwarmServicesResponseHandler cluster_manager_DockerSwarmServicesResponseHandler;

typedef struct topology_RouterRunner topology_RouterRunner;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val collections_HashMap_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val;

/*
A Mersenne Twister. This is a non-cryptographic random number generator.
*/
typedef struct random_MT random_MT;

typedef struct network_$33$24_U64_val network_$33$24_U64_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val;

typedef struct routing_$35$72_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val routing_$35$72_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val;

typedef struct t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag;

typedef struct metrics__MetricsReporter metrics__MetricsReporter;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_collections_List_time_Timer_ref_ref Array_collections_List_time_Timer_ref_ref;

typedef struct initialization_$15$52 initialization_$15$52;

typedef struct u3_t2_U8_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U8_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_val collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_val;

typedef struct u3_tcp_sink_TCPSink_tag_tcp_sink_EmptySink_tag_boundary_OutgoingBoundary_tag u3_tcp_sink_TCPSink_tag_tcp_sink_EmptySink_tag_boundary_OutgoingBoundary_tag;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val;

typedef struct u2_StdinNotify_ref_None_val u2_StdinNotify_ref_None_val;

typedef struct u3_t2_String_val_metrics__MetricsReporter_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_metrics__MetricsReporter_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u3_t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u2_topology_Initializable_tag_None_val u2_topology_Initializable_tag_None_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_topology_StateSubpartition_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_topology_StateSubpartition_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_ref collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_ref;

typedef struct u6_files_FileOK_val_files_FileError_val_files_FileEOF_val_files_FileBadFileNumber_val_files_FileExists_val_files_FilePermissionDenied_val u6_files_FileOK_val_files_FileError_val_files_FileEOF_val_files_FileBadFileNumber_val_files_FileExists_val_files_FilePermissionDenied_val;

typedef struct recovery_$37$10 recovery_$37$10;

/*
End of the line route.

We are leaving this process, to either another Wallaroo process
or to an external system.

The only route out of this step is to terminate here. Unlike filtering,
termination can either be immediate (like filtering) or can be delayed
such as "terminate this tuple once we know it has been sent by the sink".
*/
typedef struct routing_TerminusRoute routing_TerminusRoute;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_U64_val_collections_HashEq_String_val_val collections_HashMap_String_val_U64_val_collections_HashEq_String_val_val;

typedef struct messages_CreateDataChannelListener messages_CreateDataChannelListener;

typedef struct u3_t2_USize_val_wallaroo_InitFile_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_USize_val_wallaroo_InitFile_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct messages_ReplayBoundaryCountMsg messages_ReplayBoundaryCountMsg;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_pony_CPPKey_val Array_pony_CPPKey_val;

typedef struct wall_clock_WallClock wall_clock_WallClock;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box;

typedef struct topology_KeyedPartitionAddresses_U64_val topology_KeyedPartitionAddresses_U64_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct boundary_$10$17_topology_StateProcessor_pony_CPPState_ref_val boundary_$10$17_topology_StateProcessor_pony_CPPState_ref_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_U128_val Array_U128_val;

typedef struct topology_$36$103_pony_CPPData_val topology_$36$103_pony_CPPData_val;

typedef struct topology_$36$114_pony_CPPData_val_U64_val topology_$36$114_pony_CPPData_val_U64_val;

/*
This initialises SSL when the program begins.
*/
typedef struct ssl__SSLInit ssl__SSLInit;

typedef struct u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct initialization_$15$67 initialization_$15$67;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_ref ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_ref;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_val collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_val;

typedef struct boundary_$10$27 boundary_$10$27;

typedef struct initialization_$15$62 initialization_$15$62;

typedef struct files_FileEOF files_FileEOF;

typedef struct messages_CreateConnectionsMsg messages_CreateConnectionsMsg;

typedef struct ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_box ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_box;

typedef struct topology_$36$113_pony_CPPData_val_U64_val topology_$36$113_pony_CPPData_val_U64_val;

typedef struct messages_ReconnectDataPortMsg messages_ReconnectDataPortMsg;

typedef struct t2_options__Option_ref_USize_val t2_options__Option_ref_USize_val;

/*
'This should never happen' error encountered. Bail out of our running
program. Print where the error happened and exit.
*/
typedef struct fail_Fail fail_Fail;

typedef struct u2_t2_U128_val_topology_SourceData_val_None_val u2_t2_U128_val_topology_SourceData_val_None_val;

typedef struct topology_$36$119_U8_val topology_$36$119_U8_val;

typedef struct topology_DirectRouter topology_DirectRouter;

typedef struct http_URLPartHost http_URLPartHost;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct ArrayValues_options__Option_ref_Array_options__Option_ref_val ArrayValues_options__Option_ref_Array_options__Option_ref_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_val collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_val;

/*
This stores a UNIX-style mode broken out into a Bool for each bit. For other
operating systems, the mapping will be approximate. For example, on Windows,
if the file is readable all the read Bools will be set, and if the file is
writeable, all the write Bools will be set.

The default mode is read/write for the owner, read-only for everyone else.
*/
typedef struct files_FileMode files_FileMode;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_ref collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_ref;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val;

/*
Worker type providing simple to string conversions for numbers.
*/
typedef struct _ToString _ToString;

typedef struct t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val;

typedef struct pony_CPPStateChangeRepositoryHelper pony_CPPStateChangeRepositoryHelper;

typedef struct u3_t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct network_$33$25 network_$33$25;

typedef struct collections_HashIs_time_Timer_tag collections_HashIs_time_Timer_tag;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u2_http_Payload_val_None_val u2_http_Payload_val_None_val;

typedef struct u3_Array_String_val_val_topology_ProxyAddress_val_topology_PartitionAddresses_val u3_Array_String_val_val_topology_ProxyAddress_val_topology_PartitionAddresses_val;

typedef struct tcp_sink_$41$6_pony_CPPData_val tcp_sink_$41$6_pony_CPPData_val;

typedef struct t2_U128_val_U64_val t2_U128_val_U64_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_time_Timer_tag_time_Timer_ref_collections_HashIs_time_Timer_tag_val collections_HashMap_time_Timer_tag_time_Timer_ref_collections_HashIs_time_Timer_tag_val;

typedef struct u4_options_UnrecognisedOption_val_options_MissingArgument_val_options_InvalidArgument_val_options_AmbiguousMatch_val u4_options_UnrecognisedOption_val_options_MissingArgument_val_options_InvalidArgument_val_options_AmbiguousMatch_val;

typedef struct t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref;

/*
An iterator over the keys in a map.
*/
typedef struct collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_topology_Step_tag_topology_Step_tag_collections_HashIs_topology_Step_tag_val collections_HashMap_topology_Step_tag_topology_Step_tag_collections_HashIs_topology_Step_tag_val;

typedef struct routing_DummyConsumer routing_DummyConsumer;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct t2_String_val_u4_None_val_String_val_I64_val_F64_val t2_String_val_u4_None_val_String_val_I64_val_F64_val;

typedef struct u3_t2_time_Timer_tag_time_Timer_ref_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_time_Timer_tag_time_Timer_ref_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct u2_u2_topology_Step_tag_topology_ProxyRouter_val_None_val u2_u2_topology_Step_tag_topology_ProxyRouter_val_None_val;

typedef struct recovery_$37$11 recovery_$37$11;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_U8_val_pony_CPPState_ref topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_U8_val_pony_CPPState_ref;

typedef struct boundary_BoundaryNotify boundary_BoundaryNotify;

typedef struct u4_None_val_String_val_I64_val_F64_val u4_None_val_String_val_I64_val_F64_val;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_box collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_box;

typedef struct t2_U32_val_Pointer_Pointer_U8_val_tag_tag t2_U32_val_Pointer_Pointer_U8_val_tag_tag;

typedef struct net_DNSAuth net_DNSAuth;

typedef struct t2_String_val_topology_PartitionAddresses_val t2_String_val_topology_PartitionAddresses_val;

typedef struct ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_box ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_box;

typedef struct u3_t2_U128_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U128_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct messages_KeyedStepMigrationMsg_U64_val messages_KeyedStepMigrationMsg_U64_val;

typedef struct hub_HubProtocol hub_HubProtocol;

typedef struct u3_t2_routing_Consumer_tag_routing_Route_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_routing_Consumer_tag_routing_Route_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct pony_$2$8 pony_$2$8;

/*
An iterator over the values in a set.
*/
typedef struct collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_box collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_box;

typedef struct tcp_source__SourceBuilder_pony_CPPData_val tcp_source__SourceBuilder_pony_CPPData_val;

/*
Handles responses to HTTP requests.
*/
typedef struct http_ResponseHandler http_ResponseHandler;

typedef struct messages1_ExternalMsgEncoder messages1_ExternalMsgEncoder;

typedef struct wallaroo_InitFile wallaroo_InitFile;

typedef struct u3_t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct topology_Partition_pony_CPPData_val_U64_val topology_Partition_pony_CPPData_val_U64_val;

typedef struct u4_files__PathSep_val_files__PathDot_val_files__PathDot2_val_files__PathOther_val u4_files__PathSep_val_files__PathDot_val_files__PathDot2_val_files__PathOther_val;

/*
Represents an IPv4 or IPv6 address. The family field indicates the address
type. The addr field is either the IPv4 address or the IPv6 flow info. The
addr1-4 fields are the IPv6 address, or invalid for an IPv4 address. The
scope field is the IPv6 scope, or invalid for an IPv4 address.
*/
typedef struct net_IPAddress net_IPAddress;

typedef struct files_FilePermissionDenied files_FilePermissionDenied;

typedef struct routing_$35$15 routing_$35$15;

typedef struct u3_t2_U8_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U8_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_tcp_sink_TCPSink_tag Array_tcp_sink_TCPSink_tag;

typedef struct t2_boundary__BoundaryId_val_boundary_DataReceiver_tag t2_boundary__BoundaryId_val_boundary_DataReceiver_tag;

typedef struct u2_topology_Step_tag_topology_ProxyRouter_val u2_topology_Step_tag_topology_ProxyRouter_val;

typedef struct time__ClockRealtime time__ClockRealtime;

typedef struct routing_$35$95 routing_$35$95;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val;

typedef struct t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections_HashIs_data_channel_DataChannelListener_tag_val collections_HashMap_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections_HashIs_data_channel_DataChannelListener_tag_val;

typedef struct data_channel_$45$9 data_channel_$45$9;

/*
DockerSwarmClusterManager

Provides a way to dynamically create a new Wallaroo worker given a running
Docker Swarm manager's address and the control port for the worker's in that
Docker Swarm cluster.

TODO:
The HTTP client and it's handlers will need to be replaced/restructured when
the new HTTP package is pulled in from latest ponyc.
*/
typedef struct cluster_manager_DockerSwarmClusterManager cluster_manager_DockerSwarmClusterManager;

typedef struct pony_CPPComputationBuilder pony_CPPComputationBuilder;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val;

typedef struct routing_EmptyRoute routing_EmptyRoute;

/*
This message is sent from a worker requesting to join a running cluster to
any existing worker in the cluster.
*/
typedef struct messages_JoinClusterMsg messages_JoinClusterMsg;

typedef struct data_channel_$45$6 data_channel_$45$6;

typedef struct $0$13_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag $0$13_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val collections_HashMap_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val;

typedef struct routing_EmptyRouteBuilder routing_EmptyRouteBuilder;

typedef struct messages_AnnounceNewStatefulStepMsg messages_AnnounceNewStatefulStepMsg;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val;

/*
MetricsMonitor

Interface for hooking into a MetricsReporter and being able to
monitor metrics via on_send prior to a send_metrics() call.
*/
typedef struct metrics_MetricsMonitor metrics_MetricsMonitor;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct boundary_$10$18_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val boundary_$10$18_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref;

typedef struct initialization_InitFileReader initialization_InitFileReader;

typedef struct ArrayValues_String_val_Array_String_val_ref ArrayValues_String_val_Array_String_val_ref;

typedef struct t2_U128_val_topology_Router_val t2_U128_val_topology_Router_val;

/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_box collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_box;

typedef struct network_$33$35 network_$33$35;

typedef struct routing_Producer routing_Producer;

typedef struct topology_OmniRouter topology_OmniRouter;

typedef struct u2_collections_ListNode_http_Payload_val_ref_None_val u2_collections_ListNode_http_Payload_val_ref_None_val;

typedef struct files__PathDot files__PathDot;

typedef struct ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_ref ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_ref;

typedef struct u2_None_val_wallaroo_Application_ref u2_None_val_wallaroo_Application_ref;

typedef struct t2_ISize_val_String_val t2_ISize_val_String_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct u2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_None_val u2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_None_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_ref collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_ref;

/*
A quadratic probing hash map. Resize occurs at a load factor of 0.75. A
resized map has 2 times the space. The hash function can be plugged in to the
type to create different kinds of maps.
*/
typedef struct collections_HashMap_String_val_topology_PartitionAddresses_val_collections_HashEq_String_val_val collections_HashMap_String_val_topology_PartitionAddresses_val_collections_HashEq_String_val_val;

typedef struct messages_ChannelMsgEncoder messages_ChannelMsgEncoder;

typedef struct topology_$36$121 topology_$36$121;

typedef struct files_FileRead files_FileRead;

typedef struct time__ClockMonotonic time__ClockMonotonic;

typedef struct i2_ReadSeq_U8_val_box_ReadElement_U8_val_box i2_ReadSeq_U8_val_box_ReadElement_U8_val_box;

typedef struct network_ControlChannelConnectNotifier network_ControlChannelConnectNotifier;

typedef struct t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val;

typedef struct u3_t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_box collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_box;

/*
An iterator over the keys and values in a map.
*/
typedef struct collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_box collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_box;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct recovery_$37$24 recovery_$37$24;

typedef struct topology_$36$114_pony_CPPData_val_U8_val topology_$36$114_pony_CPPData_val_U8_val;

typedef struct u3_metrics_ComputationCategory_val_metrics_StartToEndCategory_val_metrics_NodeIngressEgressCategory_val u3_metrics_ComputationCategory_val_metrics_StartToEndCategory_val_metrics_NodeIngressEgressCategory_val;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct recovery_$37$28 recovery_$37$28;

typedef struct u2_topology_Router_val_None_val u2_topology_Router_val_None_val;

typedef struct u2_t2_String_val_u4_None_val_String_val_I64_val_F64_val_options_ParseError_ref u2_t2_String_val_u4_None_val_String_val_I64_val_F64_val_options_ParseError_ref;

typedef struct routing_$35$75_pony_CPPData_val_pony_CPPData_val routing_$35$75_pony_CPPData_val_pony_CPPData_val;

typedef struct boundary_$10$26 boundary_$10$26;

typedef struct recovery_$37$15 recovery_$37$15;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_u3_t2_topology_Step_tag_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val Array_u3_t2_topology_Step_tag_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val;

typedef struct collections_HashIs_net_TCPListener_tag collections_HashIs_net_TCPListener_tag;

typedef struct t5_routing_Producer_tag_U128_val_None_val_U64_val_U64_val t5_routing_Producer_tag_U128_val_None_val_U64_val_U64_val;

typedef struct t2_collections_ListNode_time_Timer_ref_ref_collections_ListNode_time_Timer_ref_ref t2_collections_ListNode_time_Timer_ref_ref_collections_ListNode_time_Timer_ref_ref;

/*
Used to show that a ReadSeq can return an element of a specific unmodified
type.
*/
typedef struct ReadElement_U8_val ReadElement_U8_val;

typedef struct initialization_$15$53 initialization_$15$53;

typedef struct ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_box ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_box;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
/*
An iterator over the values in a map.
*/
typedef struct collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_box collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_box;

/*
This represents serialised data. How it can be used depends on the other
capabilities a caller holds.
*/
typedef struct serialise_Serialised serialise_Serialised;

typedef struct topology_$36$130 topology_$36$130;

typedef struct topology_SourceData topology_SourceData;

/*
A timing wheel in a hierarchical set of timing wheels. Each wheel covers 6
bits of precision.
*/
typedef struct time__TimingWheel time__TimingWheel;

typedef struct boundary__EmptyTimerInit boundary__EmptyTimerInit;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_USize_val Array_USize_val;

typedef struct topology_$36$127 topology_$36$127;

typedef struct ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_val ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_val;

typedef struct initialization_$15$71 initialization_$15$71;

typedef struct messages1_ExternalStartGilesSendersMsg messages1_ExternalStartGilesSendersMsg;

/*
A Pointer[A] is a raw memory pointer. It has no descriptor and thus can't be
included in a union or intersection, or be a subtype of any interface. Most
functions on a Pointer[A] are private to maintain memory safety.
*/
typedef struct rebalancing_PartitionRebalancer rebalancing_PartitionRebalancer;

/*
Contiguous, resizable memory to store elements of type A.
*/
typedef struct Array_wallaroo_BasicPipeline_ref Array_wallaroo_BasicPipeline_ref;

typedef struct u2_t2_u2_String_val_Array_U8_val_val_USize_val_None_val u2_t2_u2_String_val_Array_U8_val_val_USize_val_None_val;

typedef struct t2_I64_val_I64_val t2_I64_val_I64_val;

typedef struct u2_Array_topology_PreStateData_val_val_None_val u2_Array_topology_PreStateData_val_val_None_val;

typedef struct messages1_ExternalShutdownMsg messages1_ExternalShutdownMsg;

typedef struct ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_val ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_val;

typedef struct u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val;

/*
An environment holds the command line and other values injected into the
program by default by the runtime.
*/
typedef struct Env Env;

typedef struct collections_HashIs_topology_Initializable_tag collections_HashIs_topology_Initializable_tag;

/* Allocate a u3_t2_String_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a buffered_Writer without initialising it. */
buffered_Writer* buffered_Writer_Alloc();

/* Allocate a Array_u3_t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_val without initialising it. */
collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_val* collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_ref without initialising it. */
ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_ref* ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_ref_Alloc();

/* Allocate a ArrayValues_U64_val_Array_U64_val_val without initialising it. */
ArrayValues_U64_val_Array_U64_val_val* ArrayValues_U64_val_Array_U64_val_val_Alloc();

/* Allocate a Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref without initialising it. */
Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref* Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Alloc();

/* Allocate a Array_u3_t2_U64_val_routing__Route_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U64_val_routing__Route_ref_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U64_val_routing__Route_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_KeyedStateSubpartition_pony_CPPData_val_U64_val without initialising it. */
topology_KeyedStateSubpartition_pony_CPPData_val_U64_val* topology_KeyedStateSubpartition_pony_CPPData_val_U64_val_Alloc();

/* Allocate a topology_$36$115 without initialising it. */
topology_$36$115* topology_$36$115_Alloc();

/* Allocate a collections_HashMap_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val without initialising it. */
collections_HashMap_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val* collections_HashMap_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_Alloc();

/* Allocate a u2_options__Option_ref_options_ParseError_ref without initialising it. */
u2_options__Option_ref_options_ParseError_ref* u2_options__Option_ref_options_ParseError_ref_Alloc();

/* Allocate a serialise_SerialiseAuth without initialising it. */
serialise_SerialiseAuth* serialise_SerialiseAuth_Alloc();

/* Allocate a Array_u3_t2_Any_tag_Any_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_Any_tag_Any_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_Any_tag_Any_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a t2_routing_Consumer_tag_routing_Route_box without initialising it. */
t2_routing_Consumer_tag_routing_Route_box* t2_routing_Consumer_tag_routing_Route_box_Alloc();

/* Allocate a u3_t2_String_val_net_TCPConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_net_TCPConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_net_TCPConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_routing__Route_ref_None_val without initialising it. */
u2_routing__Route_ref_None_val* u2_routing__Route_ref_None_val_Alloc();

/* Allocate a collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val without initialising it. */
collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val* collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_Alloc();

/* Allocate a routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val without initialising it. */
routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val* routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val_Alloc();

/* Allocate a u2_routing_Route_ref_None_val without initialising it. */
u2_routing_Route_ref_None_val* u2_routing_Route_ref_None_val_Alloc();

/* Allocate a $0$1_String_val without initialising it. */
$0$1_String_val* $0$1_String_val_Alloc();

/* Allocate a data_channel_DataChannelListener without initialising it. */
data_channel_DataChannelListener* data_channel_DataChannelListener_Alloc();

/* Allocate a ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_ref without initialising it. */
ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_ref* ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_ref_Alloc();

/* Allocate a messages_KeyedAnnounceNewStatefulStepMsg_U8_val without initialising it. */
messages_KeyedAnnounceNewStatefulStepMsg_U8_val* messages_KeyedAnnounceNewStatefulStepMsg_U8_val_Alloc();

/* Allocate a net_NetAuth without initialising it. */
net_NetAuth* net_NetAuth_Alloc();

/* Allocate a topology_$36$135_pony_CPPKey_val without initialising it. */
topology_$36$135_pony_CPPKey_val* topology_$36$135_pony_CPPKey_val_Alloc();

/* Allocate a Array_u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_topology_PartitionBuilder_val_None_val without initialising it. */
u2_topology_PartitionBuilder_val_None_val* u2_topology_PartitionBuilder_val_None_val_Alloc();

/* Allocate a collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val without initialising it. */
collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val* collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_Alloc();

/* Allocate a u2_pony_CPPData_val_None_val without initialising it. */
u2_pony_CPPData_val_None_val* u2_pony_CPPData_val_None_val_Alloc();

/* Allocate a t2_U128_val_topology_SourceData_val without initialising it. */
t2_U128_val_topology_SourceData_val* t2_U128_val_topology_SourceData_val_Alloc();

/* Allocate a t2_Array_U8_val_val_USize_val without initialising it. */
t2_Array_U8_val_val_USize_val* t2_Array_U8_val_val_USize_val_Alloc();

/* Allocate a Array_u2_String_val_Array_U8_val_val without initialising it. */
Array_u2_String_val_Array_U8_val_val* Array_u2_String_val_Array_U8_val_val_Alloc();

/* Allocate a collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_val without initialising it. */
collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_val* collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_val_Alloc();

/* Allocate a u2_collections_ListNode_time_Timer_ref_val_None_val without initialising it. */
u2_collections_ListNode_time_Timer_ref_val_None_val* u2_collections_ListNode_time_Timer_ref_val_None_val_Alloc();

/* Allocate a boundary_$10$22 without initialising it. */
boundary_$10$22* boundary_$10$22_Alloc();

/* Allocate a ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_ref without initialising it. */
ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_ref* ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_ref_Alloc();

/* Allocate a topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_U8_val without initialising it. */
topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_U8_val* topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_U8_val_Alloc();

/* Allocate a Array_topology_StepBuilder_val without initialising it. */
Array_topology_StepBuilder_val* Array_topology_StepBuilder_val_Alloc();

/* Allocate a u3_Less_val_Equal_val_Greater_val without initialising it. */
u3_Less_val_Equal_val_Greater_val* u3_Less_val_Equal_val_Greater_val_Alloc();

/* Allocate a options_AmbiguousMatch without initialising it. */
options_AmbiguousMatch* options_AmbiguousMatch_Alloc();

/* Allocate a recovery__NotRecovering without initialising it. */
recovery__NotRecovering* recovery__NotRecovering_Alloc();

/* Allocate a t2_String_val_boundary_OutgoingBoundary_tag without initialising it. */
t2_String_val_boundary_OutgoingBoundary_tag* t2_String_val_boundary_OutgoingBoundary_tag_Alloc();

/* Allocate a Array_u3_t2_String_val_metrics__MetricsReporter_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_metrics__MetricsReporter_ref_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_metrics__MetricsReporter_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_$36$132 without initialising it. */
topology_$36$132* topology_$36$132_Alloc();

/* Allocate a topology_$36$104 without initialising it. */
topology_$36$104* topology_$36$104_Alloc();

/* Allocate a u3_t2_net_TCPListener_tag_net_TCPListener_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_net_TCPListener_tag_net_TCPListener_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_net_TCPListener_tag_net_TCPListener_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a $0$13_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref without initialising it. */
$0$13_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref* $0$13_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Alloc();

/* Allocate a routing_$35$96_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val without initialising it. */
routing_$35$96_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val* routing_$35$96_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val_Alloc();

/* Allocate a ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_ref without initialising it. */
ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_ref* ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_ref_Alloc();

/* Allocate a collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val* collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_Alloc();

/* Allocate a $0$1_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref without initialising it. */
$0$1_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref* $0$1_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Alloc();

/* Allocate a t2_String_iso_String_iso without initialising it. */
t2_String_iso_String_iso* t2_String_iso_String_iso_Alloc();

/* Allocate a collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_ref without initialising it. */
collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_ref* collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_ref_Alloc();

/* Allocate a ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_val without initialising it. */
ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_val* ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_val_Alloc();

/* Allocate a u2_http_ResponseHandler_val_None_val without initialising it. */
u2_http_ResponseHandler_val_None_val* u2_http_ResponseHandler_val_None_val_Alloc();

/* Allocate a Array_u3_t2_String_val_initialization_LocalTopology_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_initialization_LocalTopology_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_initialization_LocalTopology_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u3_t2_String_val_boundary_OutgoingBoundary_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_boundary_OutgoingBoundary_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_boundary_OutgoingBoundary_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_Any_tag_None_val without initialising it. */
u2_Any_tag_None_val* u2_Any_tag_None_val_Alloc();

/* Allocate a topology_$36$101_pony_CPPData_val without initialising it. */
topology_$36$101_pony_CPPData_val* topology_$36$101_pony_CPPData_val_Alloc();

/* Allocate a ByteSeqIter without initialising it. */
ByteSeqIter* ByteSeqIter_Alloc();

/* Allocate a messages1__Done without initialising it. */
messages1__Done* messages1__Done_Alloc();

/* Allocate a u2_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_None_val without initialising it. */
u2_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_None_val* u2_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_None_val_Alloc();

/* Allocate a Array_topology_PreStateData_val without initialising it. */
Array_topology_PreStateData_val* Array_topology_PreStateData_val_Alloc();

/* Allocate a ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_box without initialising it. */
ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_box* ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_box_Alloc();

/* Allocate a collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_val without initialising it. */
collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_val* collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_val_Alloc();

/* Allocate a t2_topology_Step_tag_topology_Step_tag without initialising it. */
t2_topology_Step_tag_topology_Step_tag* t2_topology_Step_tag_topology_Step_tag_Alloc();

/* Allocate a t2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_collections_ListNode_t2_Array_U8_val_val_USize_val_ref without initialising it. */
t2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_collections_ListNode_t2_Array_U8_val_val_USize_val_ref* t2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_Alloc();

/* Allocate a u3_t2_String_val_topology_PartitionAddresses_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_topology_PartitionAddresses_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_topology_PartitionAddresses_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_EgressBuilder without initialising it. */
topology_EgressBuilder* topology_EgressBuilder_Alloc();

/* Allocate a ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_ref without initialising it. */
ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_ref* ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_ref_Alloc();

/* Allocate a t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box without initialising it. */
t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box* t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_Alloc();

/* Allocate a files__PathSep without initialising it. */
files__PathSep* files__PathSep_Alloc();

/* Allocate a Array_U64_val without initialising it. */
Array_U64_val* Array_U64_val_Alloc();

/* Allocate a collections_HashIs_U128_val without initialising it. */
collections_HashIs_U128_val* collections_HashIs_U128_val_Alloc();

/* Allocate a topology_RunnableStep without initialising it. */
topology_RunnableStep* topology_RunnableStep_Alloc();

/* Allocate a t2_time_Timer_tag_time_Timer_ref without initialising it. */
t2_time_Timer_tag_time_Timer_ref* t2_time_Timer_tag_time_Timer_ref_Alloc();

/* Allocate a topology_Step without initialising it. */
topology_Step* topology_Step_Alloc();

/* Allocate a u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val without initialising it. */
u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val* u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_Alloc();

/* Allocate a collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_ref* collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val* collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_val without initialising it. */
ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_val* ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_val_Alloc();

/* Allocate a t2_U32_val_U8_val without initialising it. */
t2_U32_val_U8_val* t2_U32_val_U8_val_Alloc();

/* Allocate a ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_box without initialising it. */
ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_box* ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_box_Alloc();

/* Allocate a Array_t3_U8_val_U128_val_topology_Step_tag without initialising it. */
Array_t3_U8_val_U128_val_topology_Step_tag* Array_t3_U8_val_U128_val_topology_Step_tag_Alloc();

/* Allocate a t2_String_val_metrics__MetricsReporter_box without initialising it. */
t2_String_val_metrics__MetricsReporter_box* t2_String_val_metrics__MetricsReporter_box_Alloc();

/* Allocate a topology_$36$97 without initialising it. */
topology_$36$97* topology_$36$97_Alloc();

/* Allocate a collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_val without initialising it. */
collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_val* collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_val_Alloc();

/* Allocate a collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_box without initialising it. */
collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_box* collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a recovery_Resilient without initialising it. */
recovery_Resilient* recovery_Resilient_Alloc();

/* Allocate a topology_$36$125_pony_CPPKey_val without initialising it. */
topology_$36$125_pony_CPPKey_val* topology_$36$125_pony_CPPKey_val_Alloc();

/* Allocate a String without initialising it. */
String* String_Alloc();

/* Allocate a u2_data_channel_DataChannelListener_tag_None_val without initialising it. */
u2_data_channel_DataChannelListener_tag_None_val* u2_data_channel_DataChannelListener_tag_None_val_Alloc();

/* Allocate a initialization_InitFileNotify without initialising it. */
initialization_InitFileNotify* initialization_InitFileNotify_Alloc();

/* Allocate a u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val without initialising it. */
u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val* u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_Alloc();

/* Allocate a u3_t2_U128_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U128_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U128_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag without initialising it. */
t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag* t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Alloc();

/* Allocate a u2_time__ClockRealtime_val_time__ClockMonotonic_val without initialising it. */
u2_time__ClockRealtime_val_time__ClockMonotonic_val* u2_time__ClockRealtime_val_time__ClockMonotonic_val_Alloc();

/* Allocate a collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_val without initialising it. */
collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_val* collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a Array_u3_t2_USize_val_wallaroo_InitFile_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_USize_val_wallaroo_InitFile_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_USize_val_wallaroo_InitFile_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a routing__Route without initialising it. */
routing__Route* routing__Route_Alloc();

/* Allocate a serialise_DeserialiseAuth without initialising it. */
serialise_DeserialiseAuth* serialise_DeserialiseAuth_Alloc();

/* Allocate a metrics_$29$10 without initialising it. */
metrics_$29$10* metrics_$29$10_Alloc();

/* Allocate a pony_CPPStateChange without initialising it. */
pony_CPPStateChange* pony_CPPStateChange_Alloc();

/* Allocate a Array_Array_u2_String_val_Array_U8_val_val_val without initialising it. */
Array_Array_u2_String_val_Array_U8_val_val_val* Array_Array_u2_String_val_Array_U8_val_val_val_Alloc();

/* Allocate a ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_box without initialising it. */
ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_box* ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_box_Alloc();

/* Allocate a u2_pony_CPPStateChange_ref_None_val without initialising it. */
u2_pony_CPPStateChange_ref_None_val* u2_pony_CPPStateChange_ref_None_val_Alloc();

/* Allocate a collections_ListNode_time_Timer_ref without initialising it. */
collections_ListNode_time_Timer_ref* collections_ListNode_time_Timer_ref_Alloc();

/* Allocate a t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn without initialising it. */
t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn* t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_Alloc();

/* Allocate a t2_String_val_U64_val without initialising it. */
t2_String_val_U64_val* t2_String_val_U64_val_Alloc();

/* Allocate a collections_List_t2_u2_String_val_Array_U8_val_val_USize_val without initialising it. */
collections_List_t2_u2_String_val_Array_U8_val_val_USize_val* collections_List_t2_u2_String_val_Array_U8_val_val_USize_val_Alloc();

/* Allocate a t2_String_val_Bool_val without initialising it. */
t2_String_val_Bool_val* t2_String_val_Bool_val_Alloc();

/* Allocate a collections_HashIs_String_val without initialising it. */
collections_HashIs_String_val* collections_HashIs_String_val_Alloc();

/* Allocate a u2_ssl_SSLContext_val_None_val without initialising it. */
u2_ssl_SSLContext_val_None_val* u2_ssl_SSLContext_val_None_val_Alloc();

/* Allocate a files__FileDes without initialising it. */
files__FileDes* files__FileDes_Alloc();

/* Allocate a collections_HashSet_routing_RouteLogic_ref_collections_HashIs_routing_RouteLogic_ref_val without initialising it. */
collections_HashSet_routing_RouteLogic_ref_collections_HashIs_routing_RouteLogic_ref_val* collections_HashSet_routing_RouteLogic_ref_collections_HashIs_routing_RouteLogic_ref_val_Alloc();

/* Allocate a u3_t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a http_URLPartPassword without initialising it. */
http_URLPartPassword* http_URLPartPassword_Alloc();

/* Allocate a StdStream without initialising it. */
StdStream* StdStream_Alloc();

/* Allocate a u2_collections_List_time_Timer_ref_ref_None_val without initialising it. */
u2_collections_List_time_Timer_ref_ref_None_val* u2_collections_List_time_Timer_ref_ref_None_val_Alloc();

/* Allocate a data_channel_DataChannel without initialising it. */
data_channel_DataChannel* data_channel_DataChannel_Alloc();

/* Allocate a recovery_EventLog without initialising it. */
recovery_EventLog* recovery_EventLog_Alloc();

/* Allocate a topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref without initialising it. */
topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref* topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_Alloc();

/* Allocate a collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_val without initialising it. */
collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_val* collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_val_Alloc();

/* Allocate a messages_MuteRequestMsg without initialising it. */
messages_MuteRequestMsg* messages_MuteRequestMsg_Alloc();

/* Allocate a Array_u3_t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a messages_AckMigrationBatchCompleteMsg without initialising it. */
messages_AckMigrationBatchCompleteMsg* messages_AckMigrationBatchCompleteMsg_Alloc();

/* Allocate a collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val without initialising it. */
collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val* collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val_Alloc();

/* Allocate a collections_Range_USize_val without initialising it. */
collections_Range_USize_val* collections_Range_USize_val_Alloc();

/* Allocate a messages_KeyedAnnounceNewStatefulStepMsg_U64_val without initialising it. */
messages_KeyedAnnounceNewStatefulStepMsg_U64_val* messages_KeyedAnnounceNewStatefulStepMsg_U64_val_Alloc();

/* Allocate a collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_val without initialising it. */
collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_val* collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_val_Alloc();

/* Allocate a Array_u3_t2_U64_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U64_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U64_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a recovery_RecoveryReplayer without initialising it. */
recovery_RecoveryReplayer* recovery_RecoveryReplayer_Alloc();

/* Allocate a net_TCPListenNotify without initialising it. */
net_TCPListenNotify* net_TCPListenNotify_Alloc();

/* Allocate a Array_u3_t2_String_val_topology_PartitionAddresses_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_topology_PartitionAddresses_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_topology_PartitionAddresses_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_$36$122_U64_val without initialising it. */
topology_$36$122_U64_val* topology_$36$122_U64_val_Alloc();

/* Allocate a collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_box without initialising it. */
collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_box* collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a t2_USize_val_Bool_val without initialising it. */
t2_USize_val_Bool_val* t2_USize_val_Bool_val_Alloc();

/* Allocate a u2_options__Option_ref_options__ErrorPrinter_ref without initialising it. */
u2_options__Option_ref_options__ErrorPrinter_ref* u2_options__Option_ref_options__ErrorPrinter_ref_Alloc();

/* Allocate a u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val without initialising it. */
collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val* collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_Alloc();

/* Allocate a collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val without initialising it. */
collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val* collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_Alloc();

/* Allocate a boundary_$10$15_pony_CPPKey_val without initialising it. */
boundary_$10$15_pony_CPPKey_val* boundary_$10$15_pony_CPPKey_val_Alloc();

/* Allocate a t2_U8_val_topology_ProxyAddress_val without initialising it. */
t2_U8_val_topology_ProxyAddress_val* t2_U8_val_topology_ProxyAddress_val_Alloc();

/* Allocate a u2_cluster_manager_ClusterManager_tag_None_val without initialising it. */
u2_cluster_manager_ClusterManager_tag_None_val* u2_cluster_manager_ClusterManager_tag_None_val_Alloc();

/* Allocate a topology_$36$135_U64_val without initialising it. */
topology_$36$135_U64_val* topology_$36$135_U64_val_Alloc();

/* Allocate a collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_box without initialising it. */
collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_box* collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_box_Alloc();

/* Allocate a topology_$36$128 without initialising it. */
topology_$36$128* topology_$36$128_Alloc();

/* Allocate a collections_HashEq_String_val without initialising it. */
collections_HashEq_String_val* collections_HashEq_String_val_Alloc();

/* Allocate a boundary_DataReceiversSubscriber without initialising it. */
boundary_DataReceiversSubscriber* boundary_DataReceiversSubscriber_Alloc();

/* Allocate a ArrayValues_options__Option_ref_Array_options__Option_ref_box without initialising it. */
ArrayValues_options__Option_ref_Array_options__Option_ref_box* ArrayValues_options__Option_ref_Array_options__Option_ref_box_Alloc();

/* Allocate a tcp_sink_$41$6_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val without initialising it. */
tcp_sink_$41$6_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val* tcp_sink_$41$6_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val_Alloc();

/* Allocate a t2_U8_val_U8_val without initialising it. */
t2_U8_val_U8_val* t2_U8_val_U8_val_Alloc();

/* Allocate a boundary_$10$21 without initialising it. */
boundary_$10$21* boundary_$10$21_Alloc();

/* Allocate a ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_val without initialising it. */
ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_val* ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_val_Alloc();

/* Allocate a messages1__DoneShutdown without initialising it. */
messages1__DoneShutdown* messages1__DoneShutdown_Alloc();

/* Allocate a t2_U64_val_topology_ProxyAddress_val without initialising it. */
t2_U64_val_topology_ProxyAddress_val* t2_U64_val_topology_ProxyAddress_val_Alloc();

/* Allocate a collections_HashMap_routing_RouteLogic_ref_routing_RouteLogic_ref_collections_HashIs_routing_RouteLogic_ref_val without initialising it. */
collections_HashMap_routing_RouteLogic_ref_routing_RouteLogic_ref_collections_HashIs_routing_RouteLogic_ref_val* collections_HashMap_routing_RouteLogic_ref_routing_RouteLogic_ref_collections_HashIs_routing_RouteLogic_ref_val_Alloc();

/* Allocate a u3_t2_String_val_initialization_LocalTopology_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_initialization_LocalTopology_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_initialization_LocalTopology_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_ref without initialising it. */
collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_ref* collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_ref_Alloc();

/* Allocate a u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a ReadSeq_U8_val without initialising it. */
ReadSeq_U8_val* ReadSeq_U8_val_Alloc();

/* Allocate a http_URLPartPath without initialising it. */
http_URLPartPath* http_URLPartPath_Alloc();

/* Allocate a ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_box without initialising it. */
ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_box* ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_box_Alloc();

/* Allocate a ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_val without initialising it. */
ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_val* ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_val_Alloc();

/* Allocate a ArrayValues_String_ref_Array_String_ref_ref without initialising it. */
ArrayValues_String_ref_Array_String_ref_ref* ArrayValues_String_ref_Array_String_ref_ref_Alloc();

/* Allocate a initialization_LocalTopologyInitializer without initialising it. */
initialization_LocalTopologyInitializer* initialization_LocalTopologyInitializer_Alloc();

/* Allocate a files_FileSync without initialising it. */
files_FileSync* files_FileSync_Alloc();

/* Allocate a tcp_sink_$41$10 without initialising it. */
tcp_sink_$41$10* tcp_sink_$41$10_Alloc();

/* Allocate a collections_List_t2_Array_U8_val_val_USize_val without initialising it. */
collections_List_t2_Array_U8_val_val_USize_val* collections_List_t2_Array_U8_val_val_USize_val_Alloc();

/* Allocate a collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_box without initialising it. */
collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_box* collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_box_Alloc();

/* Allocate a messages_EncoderWrapper without initialising it. */
messages_EncoderWrapper* messages_EncoderWrapper_Alloc();

/* Allocate a collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box without initialising it. */
collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box* collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box_Alloc();

/* Allocate a collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_ref* collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a topology_Runner without initialising it. */
topology_Runner* topology_Runner_Alloc();

/* Allocate a collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_val without initialising it. */
collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_val* collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_val_Alloc();

/* Allocate a pony_CPPData without initialising it. */
pony_CPPData* pony_CPPData_Alloc();

/* Allocate a collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_val without initialising it. */
collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_val* collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_val_Alloc();

/* Allocate a tcp_sink_TCPSinkNotify without initialising it. */
tcp_sink_TCPSinkNotify* tcp_sink_TCPSinkNotify_Alloc();

/* Allocate a collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_box without initialising it. */
collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_box* collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_box_Alloc();

/* Allocate a messages_TopologyReadyMsg without initialising it. */
messages_TopologyReadyMsg* messages_TopologyReadyMsg_Alloc();

/* Allocate a u3_t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_$36$117 without initialising it. */
topology_$36$117* topology_$36$117_Alloc();

/* Allocate a recovery__NotRecoveryReplaying without initialising it. */
recovery__NotRecoveryReplaying* recovery__NotRecoveryReplaying_Alloc();

/* Allocate a u2_topology_OmniRouter_val_None_val without initialising it. */
u2_topology_OmniRouter_val_None_val* u2_topology_OmniRouter_val_None_val_Alloc();

/* Allocate a topology_LocalPartitionRouter_pony_CPPData_val_pony_CPPKey_val without initialising it. */
topology_LocalPartitionRouter_pony_CPPData_val_pony_CPPKey_val* topology_LocalPartitionRouter_pony_CPPData_val_pony_CPPKey_val_Alloc();

/* Allocate a t2_USize_val_U64_val without initialising it. */
t2_USize_val_U64_val* t2_USize_val_U64_val_Alloc();

/* Allocate a u3_t2_String_val_u4_None_val_String_val_I64_val_F64_val_options_ParseError_ref_None_val without initialising it. */
u3_t2_String_val_u4_None_val_String_val_I64_val_F64_val_options_ParseError_ref_None_val* u3_t2_String_val_u4_None_val_String_val_I64_val_F64_val_options_ParseError_ref_None_val_Alloc();

/* Allocate a t2_None_val_None_val without initialising it. */
t2_None_val_None_val* t2_None_val_None_val_Alloc();

/* Allocate a topology_AugmentablePartitionRouter_U64_val without initialising it. */
topology_AugmentablePartitionRouter_U64_val* topology_AugmentablePartitionRouter_U64_val_Alloc();

/* Allocate a boundary_OutgoingBoundaryBuilder without initialising it. */
boundary_OutgoingBoundaryBuilder* boundary_OutgoingBoundaryBuilder_Alloc();

/* Allocate a collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_ref* collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_ref without initialising it. */
collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_ref* collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_ref_Alloc();

/* Allocate a Array_u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a Array_U8_val without initialising it. */
Array_U8_val* Array_U8_val_Alloc();

/* Allocate a boundary_$10$12 without initialising it. */
boundary_$10$12* boundary_$10$12_Alloc();

/* Allocate a messages1_ExternalTopologyReadyMsg without initialising it. */
messages1_ExternalTopologyReadyMsg* messages1_ExternalTopologyReadyMsg_Alloc();

/* Allocate a collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_val without initialising it. */
collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_val* collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a options_I64Argument without initialising it. */
options_I64Argument* options_I64Argument_Alloc();

/* Allocate a t2_u2_pony_CPPData_val_None_val_u2_topology_StateChange_pony_CPPState_ref_ref_None_val without initialising it. */
t2_u2_pony_CPPData_val_None_val_u2_topology_StateChange_pony_CPPState_ref_ref_None_val* t2_u2_pony_CPPData_val_None_val_u2_topology_StateChange_pony_CPPState_ref_ref_None_val_Alloc();

/* Allocate a collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val without initialising it. */
collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val* collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_Alloc();

/* Allocate a Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref without initialising it. */
Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref* Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Alloc();

/* Allocate a Array_tcp_source_TCPSourceListenerBuilder_val without initialising it. */
Array_tcp_source_TCPSourceListenerBuilder_val* Array_tcp_source_TCPSourceListenerBuilder_val_Alloc();

/* Allocate a t2_U64_val_routing__Route_ref without initialising it. */
t2_U64_val_routing__Route_ref* t2_U64_val_routing__Route_ref_Alloc();

/* Allocate a recovery__BoundaryMsgReplay without initialising it. */
recovery__BoundaryMsgReplay* recovery__BoundaryMsgReplay_Alloc();

/* Allocate a collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_ref without initialising it. */
collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_ref* collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_ref_Alloc();

/* Allocate a collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val* collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_Alloc();

/* Allocate a metrics_MetricsReporter without initialising it. */
metrics_MetricsReporter* metrics_MetricsReporter_Alloc();

/* Allocate a u3_t2_time_Timer_tag_time_Timer_box_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_time_Timer_tag_time_Timer_box_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_time_Timer_tag_time_Timer_box_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a routing_RouteLogic without initialising it. */
routing_RouteLogic* routing_RouteLogic_Alloc();

/* Allocate a ArrayValues_U8_val_Array_U8_val_val without initialising it. */
ArrayValues_U8_val_Array_U8_val_val* ArrayValues_U8_val_Array_U8_val_val_Alloc();

/* Allocate a u2_net_TCPConnection_tag_None_val without initialising it. */
u2_net_TCPConnection_tag_None_val* u2_net_TCPConnection_tag_None_val_Alloc();

/* Allocate a routing_$35$75_pony_CPPData_val_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
routing_$35$75_pony_CPPData_val_topology_StateProcessor_pony_CPPState_ref_val* routing_$35$75_pony_CPPData_val_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a ArrayValues_U128_val_Array_U128_val_ref without initialising it. */
ArrayValues_U128_val_Array_U128_val_ref* ArrayValues_U128_val_Array_U128_val_ref_Alloc();

/* Allocate a t2_ISize_val_String_iso without initialising it. */
t2_ISize_val_String_iso* t2_ISize_val_String_iso_Alloc();

/* Allocate a network_$33$26 without initialising it. */
network_$33$26* network_$33$26_Alloc();

/* Allocate a u9_messages1_ExternalDataMsg_val_messages1_ExternalReadyMsg_val_messages1_ExternalTopologyReadyMsg_val_messages1_ExternalStartMsg_val_messages1_ExternalShutdownMsg_val_messages1_ExternalDoneShutdownMsg_val_messages1_ExternalDoneMsg_val_messages1_ExternalStartGilesSendersMsg_val_messages1_ExternalGilesSendersStartedMsg_val without initialising it. */
u9_messages1_ExternalDataMsg_val_messages1_ExternalReadyMsg_val_messages1_ExternalTopologyReadyMsg_val_messages1_ExternalStartMsg_val_messages1_ExternalShutdownMsg_val_messages1_ExternalDoneShutdownMsg_val_messages1_ExternalDoneMsg_val_messages1_ExternalStartGilesSendersMsg_val_messages1_ExternalGilesSendersStartedMsg_val* u9_messages1_ExternalDataMsg_val_messages1_ExternalReadyMsg_val_messages1_ExternalTopologyReadyMsg_val_messages1_ExternalStartMsg_val_messages1_ExternalShutdownMsg_val_messages1_ExternalDoneShutdownMsg_val_messages1_ExternalDoneMsg_val_messages1_ExternalStartGilesSendersMsg_val_messages1_ExternalGilesSendersStartedMsg_val_Alloc();

/* Allocate a topology_$36$7_pony_CPPState_ref without initialising it. */
topology_$36$7_pony_CPPState_ref* topology_$36$7_pony_CPPState_ref_Alloc();

/* Allocate a topology_RunnerBuilder without initialising it. */
topology_RunnerBuilder* topology_RunnerBuilder_Alloc();

/* Allocate a topology_$36$124_U8_val without initialising it. */
topology_$36$124_U8_val* topology_$36$124_U8_val_Alloc();

/* Allocate a topology_KeyedPartitionAddresses_pony_CPPKey_val without initialising it. */
topology_KeyedPartitionAddresses_pony_CPPKey_val* topology_KeyedPartitionAddresses_pony_CPPKey_val_Alloc();

/* Allocate a collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_ref without initialising it. */
collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_ref* collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_ref_Alloc();

/* Allocate a t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag without initialising it. */
t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag* t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_Alloc();

/* Allocate a http__ClientConnection without initialising it. */
http__ClientConnection* http__ClientConnection_Alloc();

/* Allocate a Array_u3_t2_routing_Consumer_tag_routing_Route_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_routing_Consumer_tag_routing_Route_ref_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_routing_Consumer_tag_routing_Route_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u3_t2_Any_tag_Any_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_Any_tag_Any_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_Any_tag_Any_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val without initialising it. */
t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val* t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_Alloc();

/* Allocate a network_JoiningConnectNotifier without initialising it. */
network_JoiningConnectNotifier* network_JoiningConnectNotifier_Alloc();

/* Allocate a initialization_$15$54 without initialising it. */
initialization_$15$54* initialization_$15$54_Alloc();

/* Allocate a u3_t2_String_val_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a boundary__TimerInit without initialising it. */
boundary__TimerInit* boundary__TimerInit_Alloc();

/* Allocate a collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_box without initialising it. */
collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_box* collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_box_Alloc();

/* Allocate a u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a tcp_source_TCPSourceListener without initialising it. */
tcp_source_TCPSourceListener* tcp_source_TCPSourceListener_Alloc();

/* Allocate a u2_Array_String_val_val_None_val without initialising it. */
u2_Array_String_val_val_None_val* u2_Array_String_val_val_None_val_Alloc();

/* Allocate a u2_Array_String_val_val_String_val without initialising it. */
u2_Array_String_val_val_String_val* u2_Array_String_val_val_String_val_Alloc();

/* Allocate a recovery_$37$31_String_val_U128_val without initialising it. */
recovery_$37$31_String_val_U128_val* recovery_$37$31_String_val_U128_val_Alloc();

/* Allocate a recovery_$37$16 without initialising it. */
recovery_$37$16* recovery_$37$16_Alloc();

/* Allocate a topology_Router without initialising it. */
topology_Router* topology_Router_Alloc();

/* Allocate a collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_ref without initialising it. */
collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_ref* collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_ref_Alloc();

/* Allocate a ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_val without initialising it. */
ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_val* ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_val_Alloc();

/* Allocate a u3_t2_boundary__BoundaryId_val_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_boundary__BoundaryId_val_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_boundary__BoundaryId_val_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a options_UnrecognisedOption without initialising it. */
options_UnrecognisedOption* options_UnrecognisedOption_Alloc();

/* Allocate a collections_List_time_Timer_ref without initialising it. */
collections_List_time_Timer_ref* collections_List_time_Timer_ref_Alloc();

/* Allocate a tcp_sink_TCPSink without initialising it. */
tcp_sink_TCPSink* tcp_sink_TCPSink_Alloc();

/* Allocate a boundary_$10$17_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val without initialising it. */
boundary_$10$17_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val* boundary_$10$17_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val_Alloc();

/* Allocate a t2_Any_tag_Any_tag without initialising it. */
t2_Any_tag_Any_tag* t2_Any_tag_Any_tag_Alloc();

/* Allocate a recovery_$37$12 without initialising it. */
recovery_$37$12* recovery_$37$12_Alloc();

/* Allocate a pony_CPPStateComputationReturnPairWrapper without initialising it. */
pony_CPPStateComputationReturnPairWrapper* pony_CPPStateComputationReturnPairWrapper_Alloc();

/* Allocate a wallaroo_$19$26 without initialising it. */
wallaroo_$19$26* wallaroo_$19$26_Alloc();

/* Allocate a topology_$36$113_pony_CPPData_val_pony_CPPKey_val without initialising it. */
topology_$36$113_pony_CPPData_val_pony_CPPKey_val* topology_$36$113_pony_CPPData_val_pony_CPPKey_val_Alloc();

/* Allocate a u2_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_None_val without initialising it. */
u2_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_None_val* u2_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_None_val_Alloc();

/* Allocate a recovery_Recovery without initialising it. */
recovery_Recovery* recovery_Recovery_Alloc();

/* Allocate a u2_topology_StateSubpartition_val_None_val without initialising it. */
u2_topology_StateSubpartition_val_None_val* u2_topology_StateSubpartition_val_None_val_Alloc();

/* Allocate a routing_$35$96_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
routing_$35$96_topology_StateProcessor_pony_CPPState_ref_val* routing_$35$96_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a wallaroo_$19$29 without initialising it. */
wallaroo_$19$29* wallaroo_$19$29_Alloc();

/* Allocate a topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_pony_CPPKey_val without initialising it. */
topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_pony_CPPKey_val* topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_pony_CPPKey_val_Alloc();

/* Allocate a routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_pony_CPPData_val without initialising it. */
routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_pony_CPPData_val* routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_pony_CPPData_val_Alloc();

/* Allocate a files_FileError without initialising it. */
files_FileError* files_FileError_Alloc();

/* Allocate a collections_HashEq_USize_val without initialising it. */
collections_HashEq_USize_val* collections_HashEq_USize_val_Alloc();

/* Allocate a t2_U16_val_String_val without initialising it. */
t2_U16_val_String_val* t2_U16_val_String_val_Alloc();

/* Allocate a collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_ref without initialising it. */
collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_ref* collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_ref_Alloc();

/* Allocate a pony_CPPStateComputation without initialising it. */
pony_CPPStateComputation* pony_CPPStateComputation_Alloc();

/* Allocate a boundary__BoundaryId without initialising it. */
boundary__BoundaryId* boundary__BoundaryId_Alloc();

/* Allocate a collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_box without initialising it. */
collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_box* collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref without initialising it. */
t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref* t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_ref* collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a collections_Flags_u16_files_FileCreate_val_files_FileChmod_val_files_FileChown_val_files_FileLink_val_files_FileLookup_val_files_FileMkdir_val_files_FileRead_val_files_FileRemove_val_files_FileRename_val_files_FileSeek_val_files_FileStat_val_files_FileSync_val_files_FileTime_val_files_FileTruncate_val_files_FileWrite_val_files_FileExec_val_U32_val without initialising it. */
collections_Flags_u16_files_FileCreate_val_files_FileChmod_val_files_FileChown_val_files_FileLink_val_files_FileLookup_val_files_FileMkdir_val_files_FileRead_val_files_FileRemove_val_files_FileRename_val_files_FileSeek_val_files_FileStat_val_files_FileSync_val_files_FileTime_val_files_FileTruncate_val_files_FileWrite_val_files_FileExec_val_U32_val* collections_Flags_u16_files_FileCreate_val_files_FileChmod_val_files_FileChown_val_files_FileLink_val_files_FileLookup_val_files_FileMkdir_val_files_FileRead_val_files_FileRemove_val_files_FileRename_val_files_FileSeek_val_files_FileStat_val_files_FileSync_val_files_FileTime_val_files_FileTruncate_val_files_FileWrite_val_files_FileExec_val_U32_val_Alloc();

/* Allocate a ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_box without initialising it. */
ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_box* ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_box_Alloc();

/* Allocate a u2_topology_Step_tag_None_val without initialising it. */
u2_topology_Step_tag_None_val* u2_topology_Step_tag_None_val_Alloc();

/* Allocate a time_Time without initialising it. */
time_Time* time_Time_Alloc();

/* Allocate a collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_box without initialising it. */
collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_box* collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a t2_routing_RouteLogic_box_routing_RouteLogic_box without initialising it. */
t2_routing_RouteLogic_box_routing_RouteLogic_box* t2_routing_RouteLogic_box_routing_RouteLogic_box_Alloc();

/* Allocate a boundary_$10$18_pony_CPPData_val without initialising it. */
boundary_$10$18_pony_CPPData_val* boundary_$10$18_pony_CPPData_val_Alloc();

/* Allocate a Array_U32_val without initialising it. */
Array_U32_val* Array_U32_val_Alloc();

/* Allocate a files__PathDot2 without initialising it. */
files__PathDot2* files__PathDot2_Alloc();

/* Allocate a ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_box without initialising it. */
ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_box* ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_box_Alloc();

/* Allocate a recovery_$37$18 without initialising it. */
recovery_$37$18* recovery_$37$18_Alloc();

/* Allocate a topology_$36$120 without initialising it. */
topology_$36$120* topology_$36$120_Alloc();

/* Allocate a topology_ProxyAddress without initialising it. */
topology_ProxyAddress* topology_ProxyAddress_Alloc();

/* Allocate a collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_val without initialising it. */
collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_val* collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_val_Alloc();

/* Allocate a u3_t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_SerializableStateRunner without initialising it. */
topology_SerializableStateRunner* topology_SerializableStateRunner_Alloc();

/* Allocate a u2_Array_t2_pony_CPPKey_val_USize_val_val_Array_pony_CPPKey_val_val without initialising it. */
u2_Array_t2_pony_CPPKey_val_USize_val_val_Array_pony_CPPKey_val_val* u2_Array_t2_pony_CPPKey_val_USize_val_val_Array_pony_CPPKey_val_val_Alloc();

/* Allocate a guid_GuidGenerator without initialising it. */
guid_GuidGenerator* guid_GuidGenerator_Alloc();

/* Allocate a messages_ReplayMsg without initialising it. */
messages_ReplayMsg* messages_ReplayMsg_Alloc();

/* Allocate a files_FileExec without initialising it. */
files_FileExec* files_FileExec_Alloc();

/* Allocate a u3_t2_http__HostService_val_http__ClientConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_http__HostService_val_http__ClientConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_http__HostService_val_http__ClientConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a t2_String_val_boundary_OutgoingBoundaryBuilder_val without initialising it. */
t2_String_val_boundary_OutgoingBoundaryBuilder_val* t2_String_val_boundary_OutgoingBoundaryBuilder_val_Alloc();

/* Allocate a u4_AmbientAuth_val_net_NetAuth_val_net_DNSAuth_val_None_val without initialising it. */
u4_AmbientAuth_val_net_NetAuth_val_net_DNSAuth_val_None_val* u4_AmbientAuth_val_net_NetAuth_val_net_DNSAuth_val_None_val_Alloc();

/* Allocate a routing_Consumer without initialising it. */
routing_Consumer* routing_Consumer_Alloc();

/* Allocate a t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref without initialising it. */
t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref* t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Alloc();

/* Allocate a topology_PartitionFunction_pony_CPPData_val_pony_CPPKey_val without initialising it. */
topology_PartitionFunction_pony_CPPData_val_pony_CPPKey_val* topology_PartitionFunction_pony_CPPData_val_pony_CPPKey_val_Alloc();

/* Allocate a net_TCPAuth without initialising it. */
net_TCPAuth* net_TCPAuth_Alloc();

/* Allocate a t2_U16_val_USize_val without initialising it. */
t2_U16_val_USize_val* t2_U16_val_USize_val_Alloc();

/* Allocate a collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_box without initialising it. */
collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_box* collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_box_Alloc();

/* Allocate a topology_StepIdRouter without initialising it. */
topology_StepIdRouter* topology_StepIdRouter_Alloc();

/* Allocate a files_FileSeek without initialising it. */
files_FileSeek* files_FileSeek_Alloc();

/* Allocate a messages_UnknownChannelMsg without initialising it. */
messages_UnknownChannelMsg* messages_UnknownChannelMsg_Alloc();

/* Allocate a collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_ref* collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val without initialising it. */
collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val* collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_Alloc();

/* Allocate a collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_box without initialising it. */
collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_box* collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_box_Alloc();

/* Allocate a recovery__EmptyReplayPhase without initialising it. */
recovery__EmptyReplayPhase* recovery__EmptyReplayPhase_Alloc();

/* Allocate a t2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val without initialising it. */
t2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val* t2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_val without initialising it. */
collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_val* collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_val_Alloc();

/* Allocate a AsioEvent without initialising it. */
AsioEvent* AsioEvent_Alloc();

/* Allocate a collections__MapEmpty without initialising it. */
collections__MapEmpty* collections__MapEmpty_Alloc();

/* Allocate a u2_collections_List_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val without initialising it. */
u2_collections_List_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val* u2_collections_List_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val_Alloc();

/* Allocate a recovery_DummyBackend without initialising it. */
recovery_DummyBackend* recovery_DummyBackend_Alloc();

/* Allocate a topology_StateComputation_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref without initialising it. */
topology_StateComputation_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref* topology_StateComputation_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_Alloc();

/* Allocate a data_channel__DataReceiverWrapper without initialising it. */
data_channel__DataReceiverWrapper* data_channel__DataReceiverWrapper_Alloc();

/* Allocate a recovery_FileBackend without initialising it. */
recovery_FileBackend* recovery_FileBackend_Alloc();

/* Allocate a Array_u3_t2_String_val_boundary_OutgoingBoundaryBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_boundary_OutgoingBoundaryBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_boundary_OutgoingBoundaryBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a network_$33$36 without initialising it. */
network_$33$36* network_$33$36_Alloc();

/* Allocate a t2_http__HostService_val_http__ClientConnection_tag without initialising it. */
t2_http__HostService_val_http__ClientConnection_tag* t2_http__HostService_val_http__ClientConnection_tag_Alloc();

/* Allocate a u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a data_channel_DataChannelNotify without initialising it. */
data_channel_DataChannelNotify* data_channel_DataChannelNotify_Alloc();

/* Allocate a Array_Array_U64_val_ref without initialising it. */
Array_Array_U64_val_ref* Array_Array_U64_val_ref_Alloc();

/* Allocate a collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_ref without initialising it. */
collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_ref* collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_ref_Alloc();

/* Allocate a t2_routing_Consumer_tag_routing_Route_val without initialising it. */
t2_routing_Consumer_tag_routing_Route_val* t2_routing_Consumer_tag_routing_Route_val_Alloc();

/* Allocate a Array_u3_t2_U8_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U8_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U8_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val without initialising it. */
collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val* collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val_Alloc();

/* Allocate a initialization_$15$70 without initialising it. */
initialization_$15$70* initialization_$15$70_Alloc();

/* Allocate a t2_String_val_None_val without initialising it. */
t2_String_val_None_val* t2_String_val_None_val_Alloc();

/* Allocate a u3_t2_U128_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U128_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U128_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_box without initialising it. */
ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_box* ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_box_Alloc();

/* Allocate a u2_collections_List_t2_USize_val_U64_val_ref_None_val without initialising it. */
u2_collections_List_t2_USize_val_U64_val_ref_None_val* u2_collections_List_t2_USize_val_U64_val_ref_None_val_Alloc();

/* Allocate a t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val without initialising it. */
t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val* t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_U64_val_pony_CPPState_ref without initialising it. */
topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_U64_val_pony_CPPState_ref* topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_U64_val_pony_CPPState_ref_Alloc();

/* Allocate a Array_u3_t2_String_val_net_TCPConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_net_TCPConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_net_TCPConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_Array_String_val_ref_None_val without initialising it. */
u2_Array_String_val_ref_None_val* u2_Array_String_val_ref_None_val_Alloc();

/* Allocate a topology_PartitionFunction_pony_CPPData_val_U64_val without initialising it. */
topology_PartitionFunction_pony_CPPData_val_U64_val* topology_PartitionFunction_pony_CPPData_val_U64_val_Alloc();

/* Allocate a topology_$36$119_U64_val without initialising it. */
topology_$36$119_U64_val* topology_$36$119_U64_val_Alloc();

/* Allocate a collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val without initialising it. */
collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val* collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_Alloc();

/* Allocate a collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_ref without initialising it. */
collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_ref* collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_ref_Alloc();

/* Allocate a t2_String_val_U128_val without initialising it. */
t2_String_val_U128_val* t2_String_val_U128_val_Alloc();

/* Allocate a tcp_sink_$41$6_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
tcp_sink_$41$6_topology_StateProcessor_pony_CPPState_ref_val* tcp_sink_$41$6_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a initialization_$15$55 without initialising it. */
initialization_$15$55* initialization_$15$55_Alloc();

/* Allocate a metrics_MetricsSink without initialising it. */
metrics_MetricsSink* metrics_MetricsSink_Alloc();

/* Allocate a t3_U64_val_U128_val_topology_Step_tag without initialising it. */
t3_U64_val_U128_val_topology_Step_tag* t3_U64_val_U128_val_topology_Step_tag_Alloc();

/* Allocate a collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_val without initialising it. */
collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_val* collections_MapPairs_U8_val_U128_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_val_Alloc();

/* Allocate a topology_StateSubpartition without initialising it. */
topology_StateSubpartition* topology_StateSubpartition_Alloc();

/* Allocate a network_$33$34 without initialising it. */
network_$33$34* network_$33$34_Alloc();

/* Allocate a pony_CPPState without initialising it. */
pony_CPPState* pony_CPPState_Alloc();

/* Allocate a topology_$36$96_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
topology_$36$96_topology_StateProcessor_pony_CPPState_ref_val* topology_$36$96_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_box without initialising it. */
collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_box* collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_box_Alloc();

/* Allocate a collections_HashMap_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections_HashEq_U128_val_val without initialising it. */
collections_HashMap_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections_HashEq_U128_val_val* collections_HashMap_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_collections_HashEq_U128_val_val_Alloc();

/* Allocate a u3_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_None_val without initialising it. */
u2_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_None_val* u2_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_None_val_Alloc();

/* Allocate a $0$13_U32_val without initialising it. */
$0$13_U32_val* $0$13_U32_val_Alloc();

/* Allocate a collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_ref* collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag without initialising it. */
t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag* t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_Alloc();

/* Allocate a Array_Array_U8_val_ref without initialising it. */
Array_Array_U8_val_ref* Array_Array_U8_val_ref_Alloc();

/* Allocate a messages_TypedEncoderWrapper_pony_CPPData_val without initialising it. */
messages_TypedEncoderWrapper_pony_CPPData_val* messages_TypedEncoderWrapper_pony_CPPData_val_Alloc();

/* Allocate a t2_U64_val_Bool_val without initialising it. */
t2_U64_val_Bool_val* t2_U64_val_Bool_val_Alloc();

/* Allocate a initialization_$15$51 without initialising it. */
initialization_$15$51* initialization_$15$51_Alloc();

/* Allocate a messages_KeyedStepMigrationMsg_pony_CPPKey_val without initialising it. */
messages_KeyedStepMigrationMsg_pony_CPPKey_val* messages_KeyedStepMigrationMsg_pony_CPPKey_val_Alloc();

/* Allocate a t2_pony_CPPKey_val_U128_val without initialising it. */
t2_pony_CPPKey_val_U128_val* t2_pony_CPPKey_val_U128_val_Alloc();

/* Allocate a ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_val without initialising it. */
ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_val* ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_val_Alloc();

/* Allocate a $0$12_routing_Producer_tag without initialising it. */
$0$12_routing_Producer_tag* $0$12_routing_Producer_tag_Alloc();

/* Allocate a initialization_$15$63 without initialising it. */
initialization_$15$63* initialization_$15$63_Alloc();

/* Allocate a u2_collections_List_http_Payload_val_ref_None_val without initialising it. */
u2_collections_List_http_Payload_val_ref_None_val* u2_collections_List_http_Payload_val_ref_None_val_Alloc();

/* Allocate a topology_$36$122_U8_val without initialising it. */
topology_$36$122_U8_val* topology_$36$122_U8_val_Alloc();

/* Allocate a options_ParseError without initialising it. */
options_ParseError* options_ParseError_Alloc();

/* Allocate a network_Connections without initialising it. */
network_Connections* network_Connections_Alloc();

/* Allocate a recovery_Backend without initialising it. */
recovery_Backend* recovery_Backend_Alloc();

/* Allocate a boundary_DataReceivers without initialising it. */
boundary_DataReceivers* boundary_DataReceivers_Alloc();

/* Allocate a ArrayValues_U8_val_Array_U8_val_ref without initialising it. */
ArrayValues_U8_val_Array_U8_val_ref* ArrayValues_U8_val_Array_U8_val_ref_Alloc();

/* Allocate a collections__MapDeleted without initialising it. */
collections__MapDeleted* collections__MapDeleted_Alloc();

/* Allocate a collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_val without initialising it. */
collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_val* collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val without initialising it. */
t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val* t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Alloc();

/* Allocate a collections_HashEq_pony_CPPKey_val without initialising it. */
collections_HashEq_pony_CPPKey_val* collections_HashEq_pony_CPPKey_val_Alloc();

/* Allocate a t3_pony_CPPKey_val_U128_val_topology_Step_tag without initialising it. */
t3_pony_CPPKey_val_U128_val_topology_Step_tag* t3_pony_CPPKey_val_U128_val_topology_Step_tag_Alloc();

/* Allocate a messages1_ExternalDoneMsg without initialising it. */
messages1_ExternalDoneMsg* messages1_ExternalDoneMsg_Alloc();

/* Allocate a http_URLPartFragment without initialising it. */
http_URLPartFragment* http_URLPartFragment_Alloc();

/* Allocate a collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_val without initialising it. */
collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_val* collections_SetValues_String_val_collections_HashIs_String_val_val_collections_HashSet_String_val_collections_HashIs_String_val_val_val_Alloc();

/* Allocate a t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box without initialising it. */
t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box* t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_Alloc();

/* Allocate a u4_None_val_options_StringArgument_val_options_I64Argument_val_options_F64Argument_val without initialising it. */
u4_None_val_options_StringArgument_val_options_I64Argument_val_options_F64Argument_val* u4_None_val_options_StringArgument_val_options_I64Argument_val_options_F64Argument_val_Alloc();

/* Allocate a u16_files_FileCreate_val_files_FileChmod_val_files_FileChown_val_files_FileLink_val_files_FileLookup_val_files_FileMkdir_val_files_FileRead_val_files_FileRemove_val_files_FileRename_val_files_FileSeek_val_files_FileStat_val_files_FileSync_val_files_FileTime_val_files_FileTruncate_val_files_FileWrite_val_files_FileExec_val without initialising it. */
u16_files_FileCreate_val_files_FileChmod_val_files_FileChown_val_files_FileLink_val_files_FileLookup_val_files_FileMkdir_val_files_FileRead_val_files_FileRemove_val_files_FileRename_val_files_FileSeek_val_files_FileStat_val_files_FileSync_val_files_FileTime_val_files_FileTruncate_val_files_FileWrite_val_files_FileExec_val* u16_files_FileCreate_val_files_FileChmod_val_files_FileChown_val_files_FileLink_val_files_FileLookup_val_files_FileMkdir_val_files_FileRead_val_files_FileRemove_val_files_FileRename_val_files_FileSeek_val_files_FileStat_val_files_FileSync_val_files_FileTime_val_files_FileTruncate_val_files_FileWrite_val_files_FileExec_val_Alloc();

/* Allocate a u2_tcp_sink_TCPSinkBuilder_val_None_val without initialising it. */
u2_tcp_sink_TCPSinkBuilder_val_None_val* u2_tcp_sink_TCPSinkBuilder_val_None_val_Alloc();

/* Allocate a u2_routing_RouteBuilder_val_None_val without initialising it. */
u2_routing_RouteBuilder_val_None_val* u2_routing_RouteBuilder_val_None_val_Alloc();

/* Allocate a $0$1_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag without initialising it. */
$0$1_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag* $0$1_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Alloc();

/* Allocate a collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_box without initialising it. */
collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_box* collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_box_Alloc();

/* Allocate a files__PathOther without initialising it. */
files__PathOther* files__PathOther_Alloc();

/* Allocate a messages_KeyedAnnounceNewStatefulStepMsg_pony_CPPKey_val without initialising it. */
messages_KeyedAnnounceNewStatefulStepMsg_pony_CPPKey_val* messages_KeyedAnnounceNewStatefulStepMsg_pony_CPPKey_val_Alloc();

/* Allocate a Array_u3_t2_String_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a messages1__TopologyReady without initialising it. */
messages1__TopologyReady* messages1__TopologyReady_Alloc();

/* Allocate a collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_val without initialising it. */
collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_val* collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_val_Alloc();

/* Allocate a topology_$36$105 without initialising it. */
topology_$36$105* topology_$36$105_Alloc();

/* Allocate a t2_String_val_initialization_LocalTopology_val without initialising it. */
t2_String_val_initialization_LocalTopology_val* t2_String_val_initialization_LocalTopology_val_Alloc();

/* Allocate a topology_$36$125_U64_val without initialising it. */
topology_$36$125_U64_val* topology_$36$125_U64_val_Alloc();

/* Allocate a ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_val without initialising it. */
ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_val* ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_val_Alloc();

/* Allocate a Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val without initialising it. */
Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val* Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Alloc();

/* Allocate a u3_t2_routing_RouteLogic_box_routing_RouteLogic_box_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_routing_RouteLogic_box_routing_RouteLogic_box_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_routing_RouteLogic_box_routing_RouteLogic_box_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_ComputationBuilder_pony_CPPData_val_pony_CPPData_val without initialising it. */
topology_ComputationBuilder_pony_CPPData_val_pony_CPPData_val* topology_ComputationBuilder_pony_CPPData_val_pony_CPPData_val_Alloc();

/* Allocate a topology_InputWrapper without initialising it. */
topology_InputWrapper* topology_InputWrapper_Alloc();

/* Allocate a topology_$36$96_pony_CPPData_val without initialising it. */
topology_$36$96_pony_CPPData_val* topology_$36$96_pony_CPPData_val_Alloc();

/* Allocate a ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_box without initialising it. */
ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_box* ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_box_Alloc();

/* Allocate a t2_USize_val_wallaroo_InitFile_val without initialising it. */
t2_USize_val_wallaroo_InitFile_val* t2_USize_val_wallaroo_InitFile_val_Alloc();

/* Allocate a collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_ref* collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a topology_PartitionBuilder without initialising it. */
topology_PartitionBuilder* topology_PartitionBuilder_Alloc();

/* Allocate a collections_HashSet_Any_tag_collections_HashIs_Any_tag_val without initialising it. */
collections_HashSet_Any_tag_collections_HashIs_Any_tag_val* collections_HashSet_Any_tag_collections_HashIs_Any_tag_val_Alloc();

/* Allocate a routing_DataReceiverRoutes without initialising it. */
routing_DataReceiverRoutes* routing_DataReceiverRoutes_Alloc();

/* Allocate a t2_String_val_topology_PartitionRouter_val without initialising it. */
t2_String_val_topology_PartitionRouter_val* t2_String_val_topology_PartitionRouter_val_Alloc();

/* Allocate a topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_U64_val without initialising it. */
topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_U64_val* topology_PartitionedStateRunnerBuilder_pony_CPPData_val_pony_CPPState_ref_U64_val_Alloc();

/* Allocate a boundary_$10$15_U8_val without initialising it. */
boundary_$10$15_U8_val* boundary_$10$15_U8_val_Alloc();

/* Allocate a u2_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_None_val without initialising it. */
u2_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_None_val* u2_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_None_val_Alloc();

/* Allocate a topology_Computation_pony_CPPData_val_pony_CPPData_val without initialising it. */
topology_Computation_pony_CPPData_val_pony_CPPData_val* topology_Computation_pony_CPPData_val_pony_CPPData_val_Alloc();

/* Allocate a routing_TypedRoute_pony_CPPData_val without initialising it. */
routing_TypedRoute_pony_CPPData_val* routing_TypedRoute_pony_CPPData_val_Alloc();

/* Allocate a files_FileWrite without initialising it. */
files_FileWrite* files_FileWrite_Alloc();

/* Allocate a collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_box without initialising it. */
collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_box* collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_box_Alloc();

/* Allocate a Array_t3_U64_val_U128_val_topology_Step_tag without initialising it. */
Array_t3_U64_val_U128_val_topology_Step_tag* Array_t3_U64_val_U128_val_topology_Step_tag_Alloc();

/* Allocate a collections_HashMap_USize_val_wallaroo_InitFile_val_collections_HashEq_USize_val_val without initialising it. */
collections_HashMap_USize_val_wallaroo_InitFile_val_collections_HashEq_USize_val_val* collections_HashMap_USize_val_wallaroo_InitFile_val_collections_HashEq_USize_val_val_Alloc();

/* Allocate a Array_u3_t2_U128_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U128_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U128_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a Less without initialising it. */
Less* Less_Alloc();

/* Allocate a u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val without initialising it. */
u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val* u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val_Alloc();

/* Allocate a topology__StringSet without initialising it. */
topology__StringSet* topology__StringSet_Alloc();

/* Allocate a u4_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_None_val without initialising it. */
u4_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_None_val* u4_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_None_val_Alloc();

/* Allocate a options_StringArgument without initialising it. */
options_StringArgument* options_StringArgument_Alloc();

/* Allocate a Array_u3_t2_U64_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U64_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U64_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a network_WallarooOutgoingNetworkActor without initialising it. */
network_WallarooOutgoingNetworkActor* network_WallarooOutgoingNetworkActor_Alloc();

/* Allocate a u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_HashMap_U64_val_Bool_val_collections_HashEq_U64_val_val without initialising it. */
collections_HashMap_U64_val_Bool_val_collections_HashEq_U64_val_val* collections_HashMap_U64_val_Bool_val_collections_HashEq_U64_val_val_Alloc();

/* Allocate a ssl__SSLContext without initialising it. */
ssl__SSLContext* ssl__SSLContext_Alloc();

/* Allocate a data_channel_DataChannelListenNotify without initialising it. */
data_channel_DataChannelListenNotify* data_channel_DataChannelListenNotify_Alloc();

/* Allocate a collections_HashMap_String_val_String_val_collections_HashIs_String_val_val without initialising it. */
collections_HashMap_String_val_String_val_collections_HashIs_String_val_val* collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_Alloc();

/* Allocate a collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_val without initialising it. */
collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_val* collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a Array_Pointer_U8_val_tag without initialising it. */
Array_Pointer_U8_val_tag* Array_Pointer_U8_val_tag_Alloc();

/* Allocate a network_JoiningListenNotifier without initialising it. */
network_JoiningListenNotifier* network_JoiningListenNotifier_Alloc();

/* Allocate a t2_collections_ListNode_time_Timer_ref_ref_None_val without initialising it. */
t2_collections_ListNode_time_Timer_ref_ref_None_val* t2_collections_ListNode_time_Timer_ref_ref_None_val_Alloc();

/* Allocate a t2_routing_Consumer_tag_routing_Route_ref without initialising it. */
t2_routing_Consumer_tag_routing_Route_ref* t2_routing_Consumer_tag_routing_Route_ref_Alloc();

/* Allocate a topology_$36$96_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val without initialising it. */
topology_$36$96_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val* topology_$36$96_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val_Alloc();

/* Allocate a routing_$35$72_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
routing_$35$72_topology_StateProcessor_pony_CPPState_ref_val* routing_$35$72_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_ref* collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a u2_wallaroo_Application_val_None_val without initialising it. */
u2_wallaroo_Application_val_None_val* u2_wallaroo_Application_val_None_val_Alloc();

/* Allocate a topology_SingleStepPartitionFunction_pony_CPPData_val without initialising it. */
topology_SingleStepPartitionFunction_pony_CPPData_val* topology_SingleStepPartitionFunction_pony_CPPData_val_Alloc();

/* Allocate a metrics_Histogram without initialising it. */
metrics_Histogram* metrics_Histogram_Alloc();

/* Allocate a collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_ref without initialising it. */
collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_ref* collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_ref_Alloc();

/* Allocate a collections_HashMap_topology_Initializable_tag_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val without initialising it. */
collections_HashMap_topology_Initializable_tag_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val* collections_HashMap_topology_Initializable_tag_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_Alloc();

/* Allocate a routing_$35$76_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
routing_$35$76_topology_StateProcessor_pony_CPPState_ref_val* routing_$35$76_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a t2_String_val_metrics__MetricsReporter_ref without initialising it. */
t2_String_val_metrics__MetricsReporter_ref* t2_String_val_metrics__MetricsReporter_ref_Alloc();

/* Allocate a data_channel_$45$7 without initialising it. */
data_channel_$45$7* data_channel_$45$7_Alloc();

/* Allocate a collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_ref without initialising it. */
collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_ref* collections_MapPairs_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_ref_Alloc();

/* Allocate a u2_u2_topology_ProxyAddress_val_U128_val_None_val without initialising it. */
u2_u2_topology_ProxyAddress_val_U128_val_None_val* u2_u2_topology_ProxyAddress_val_U128_val_None_val_Alloc();

/* Allocate a topology_Partition_pony_CPPData_val_U8_val without initialising it. */
topology_Partition_pony_CPPData_val_U8_val* topology_Partition_pony_CPPData_val_U8_val_Alloc();

/* Allocate a tcp_sink_EmptySink without initialising it. */
tcp_sink_EmptySink* tcp_sink_EmptySink_Alloc();

/* Allocate a Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val without initialising it. */
Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val* Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Alloc();

/* Allocate a topology_$36$112_pony_CPPData_val_U8_val without initialising it. */
topology_$36$112_pony_CPPData_val_U8_val* topology_$36$112_pony_CPPData_val_U8_val_Alloc();

/* Allocate a initialization_$15$73 without initialising it. */
initialization_$15$73* initialization_$15$73_Alloc();

/* Allocate a u2_Array_t2_U8_val_USize_val_val_Array_U8_val_val without initialising it. */
u2_Array_t2_U8_val_USize_val_val_Array_U8_val_val* u2_Array_t2_U8_val_USize_val_val_Array_U8_val_val_Alloc();

/* Allocate a boundary_$10$16 without initialising it. */
boundary_$10$16* boundary_$10$16_Alloc();

/* Allocate a t2_u2_options__Option_ref_None_val_USize_val without initialising it. */
t2_u2_options__Option_ref_None_val_USize_val* t2_u2_options__Option_ref_None_val_USize_val_Alloc();

/* Allocate a files__EBADF without initialising it. */
files__EBADF* files__EBADF_Alloc();

/* Allocate a messages1_ExternalDoneShutdownMsg without initialising it. */
messages1_ExternalDoneShutdownMsg* messages1_ExternalDoneShutdownMsg_Alloc();

/* Allocate a collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box without initialising it. */
collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box* collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box_Alloc();

/* Allocate a routing__FilterRoute without initialising it. */
routing__FilterRoute* routing__FilterRoute_Alloc();

/* Allocate a recovery_$37$14 without initialising it. */
recovery_$37$14* recovery_$37$14_Alloc();

/* Allocate a topology_DataRouter without initialising it. */
topology_DataRouter* topology_DataRouter_Alloc();

/* Allocate a http_Client without initialising it. */
http_Client* http_Client_Alloc();

/* Allocate a Stdin without initialising it. */
Stdin* Stdin_Alloc();

/* Allocate a data_channel_$45$10 without initialising it. */
data_channel_$45$10* data_channel_$45$10_Alloc();

/* Allocate a routing_BoundaryRoute without initialising it. */
routing_BoundaryRoute* routing_BoundaryRoute_Alloc();

/* Allocate a cluster_manager_DockerSwarmWorkerResponseHandler without initialising it. */
cluster_manager_DockerSwarmWorkerResponseHandler* cluster_manager_DockerSwarmWorkerResponseHandler_Alloc();

/* Allocate a initialization_$15$60 without initialising it. */
initialization_$15$60* initialization_$15$60_Alloc();

/* Allocate a pony_CPPSinkEncoder without initialising it. */
pony_CPPSinkEncoder* pony_CPPSinkEncoder_Alloc();

/* Allocate a pony_WallarooMain without initialising it. */
pony_WallarooMain* pony_WallarooMain_Alloc();

/* Allocate a ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_ref without initialising it. */
ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_ref* ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_ref_Alloc();

/* Allocate a pony_CPPPartitionFunctionU64 without initialising it. */
pony_CPPPartitionFunctionU64* pony_CPPPartitionFunctionU64_Alloc();

/* Allocate a routing_$35$72_pony_CPPData_val without initialising it. */
routing_$35$72_pony_CPPData_val* routing_$35$72_pony_CPPData_val_Alloc();

/* Allocate a routing_$35$94 without initialising it. */
routing_$35$94* routing_$35$94_Alloc();

/* Allocate a u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a boundary__DataReceiverAcceptingMessagesPhase without initialising it. */
boundary__DataReceiverAcceptingMessagesPhase* boundary__DataReceiverAcceptingMessagesPhase_Alloc();

/* Allocate a u2_boundary_DataReceiver_tag_None_val without initialising it. */
u2_boundary_DataReceiver_tag_None_val* u2_boundary_DataReceiver_tag_None_val_Alloc();

/* Allocate a ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_val without initialising it. */
ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_val* ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_val_Alloc();

/* Allocate a collections_HashSet_String_val_collections_HashEq_String_val_val without initialising it. */
collections_HashSet_String_val_collections_HashEq_String_val_val* collections_HashSet_String_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a messages_SpinUpLocalTopologyMsg without initialising it. */
messages_SpinUpLocalTopologyMsg* messages_SpinUpLocalTopologyMsg_Alloc();

/* Allocate a Array_time__TimingWheel_ref without initialising it. */
Array_time__TimingWheel_ref* Array_time__TimingWheel_ref_Alloc();

/* Allocate a routing_TypedRouteBuilder_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
routing_TypedRouteBuilder_topology_StateProcessor_pony_CPPState_ref_val* routing_TypedRouteBuilder_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a routing_$35$73 without initialising it. */
routing_$35$73* routing_$35$73_Alloc();

/* Allocate a data_channel__InitDataReceiver without initialising it. */
data_channel__InitDataReceiver* data_channel__InitDataReceiver_Alloc();

/* Allocate a routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val without initialising it. */
routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val* routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val_Alloc();

/* Allocate a messages_AckWatermarkMsg without initialising it. */
messages_AckWatermarkMsg* messages_AckWatermarkMsg_Alloc();

/* Allocate a u3_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val without initialising it. */
u3_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val* u3_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val_Alloc();

/* Allocate a Array_routing_Producer_tag without initialising it. */
Array_routing_Producer_tag* Array_routing_Producer_tag_Alloc();

/* Allocate a i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag without initialising it. */
i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag* i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Alloc();

/* Allocate a options__Option without initialising it. */
options__Option* options__Option_Alloc();

/* Allocate a Array_u3_t2_String_val_topology_PartitionRouter_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_topology_PartitionRouter_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_topology_PartitionRouter_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a Array_u3_t2_String_val_boundary_OutgoingBoundary_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_boundary_OutgoingBoundary_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_boundary_OutgoingBoundary_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a Array_u3_t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u3_t2_String_val_topology_PartitionBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_topology_PartitionBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_topology_PartitionBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a files_FileCreate without initialising it. */
files_FileCreate* files_FileCreate_Alloc();

/* Allocate a collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_box without initialising it. */
collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_box* collections_MapKeys_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a routing_$35$78 without initialising it. */
routing_$35$78* routing_$35$78_Alloc();

/* Allocate a routing_TypedRoute_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
routing_TypedRoute_topology_StateProcessor_pony_CPPState_ref_val* routing_TypedRoute_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag without initialising it. */
t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag* t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag_Alloc();

/* Allocate a t6_U128_val_U128_val_None_val_U64_val_U64_val_Array_U8_val_val without initialising it. */
t6_U128_val_U128_val_None_val_U64_val_U64_val_Array_U8_val_val* t6_U128_val_U128_val_None_val_U64_val_U64_val_Array_U8_val_val_Alloc();

/* Allocate a topology_$36$129 without initialising it. */
topology_$36$129* topology_$36$129_Alloc();

/* Allocate a u3_t2_String_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a Array_u3_t2_String_val_USize_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_USize_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_USize_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a network_$33$24_U8_val without initialising it. */
network_$33$24_U8_val* network_$33$24_U8_val_Alloc();

/* Allocate a ArrayValues_U128_val_Array_U128_val_val without initialising it. */
ArrayValues_U128_val_Array_U128_val_val* ArrayValues_U128_val_Array_U128_val_val_Alloc();

/* Allocate a collections_HashMap_String_val_String_val_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_String_val_collections_HashEq_String_val_val* collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a $0$0_routing_Producer_tag without initialising it. */
$0$0_routing_Producer_tag* $0$0_routing_Producer_tag_Alloc();

/* Allocate a messages_IdentifyControlPortMsg without initialising it. */
messages_IdentifyControlPortMsg* messages_IdentifyControlPortMsg_Alloc();

/* Allocate a net_TCPListenAuth without initialising it. */
net_TCPListenAuth* net_TCPListenAuth_Alloc();

/* Allocate a ArrayValues_U128_val_Array_U128_val_box without initialising it. */
ArrayValues_U128_val_Array_U128_val_box* ArrayValues_U128_val_Array_U128_val_box_Alloc();

/* Allocate a http__HostService without initialising it. */
http__HostService* http__HostService_Alloc();

/* Allocate a topology_StateRunnerBuilder_pony_CPPState_ref without initialising it. */
topology_StateRunnerBuilder_pony_CPPState_ref* topology_StateRunnerBuilder_pony_CPPState_ref_Alloc();

/* Allocate a collections_HashMap_String_val_topology_Router_val_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_topology_Router_val_collections_HashEq_String_val_val* collections_HashMap_String_val_topology_Router_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a routing_$35$77 without initialising it. */
routing_$35$77* routing_$35$77_Alloc();

/* Allocate a collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val without initialising it. */
collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val* collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_Alloc();

/* Allocate a i2_recovery_Resilient_tag_routing_Producer_tag without initialising it. */
i2_recovery_Resilient_tag_routing_Producer_tag* i2_recovery_Resilient_tag_routing_Producer_tag_Alloc();

/* Allocate a u3_t2_pony_CPPKey_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_pony_CPPKey_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_pony_CPPKey_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u3_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_None_val without initialising it. */
u3_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_None_val* u3_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_None_val_Alloc();

/* Allocate a messages1_ExternalMsg without initialising it. */
messages1_ExternalMsg* messages1_ExternalMsg_Alloc();

/* Allocate a ArrayValues_String_val_Array_String_val_val without initialising it. */
ArrayValues_String_val_Array_String_val_val* ArrayValues_String_val_Array_String_val_val_Alloc();

/* Allocate a t2_String_val_F64_val without initialising it. */
t2_String_val_F64_val* t2_String_val_F64_val_Alloc();

/* Allocate a collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_val without initialising it. */
collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_val* collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_val_Alloc();

/* Allocate a messages_ChannelMsg without initialising it. */
messages_ChannelMsg* messages_ChannelMsg_Alloc();

/* Allocate a u4_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val_net_TCPConnectAuth_val without initialising it. */
u4_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val_net_TCPConnectAuth_val* u4_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val_net_TCPConnectAuth_val_Alloc();

/* Allocate a initialization_LocalTopology without initialising it. */
initialization_LocalTopology* initialization_LocalTopology_Alloc();

/* Allocate a collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_val without initialising it. */
collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_val* collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_val_Alloc();

/* Allocate a messages_StepMigrationMsg without initialising it. */
messages_StepMigrationMsg* messages_StepMigrationMsg_Alloc();

/* Allocate a t2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref without initialising it. */
t2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref* t2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_Alloc();

/* Allocate a collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val* collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a StringRunes without initialising it. */
StringRunes* StringRunes_Alloc();

/* Allocate a messages_SinkEncoder_pony_CPPData_val without initialising it. */
messages_SinkEncoder_pony_CPPData_val* messages_SinkEncoder_pony_CPPData_val_Alloc();

/* Allocate a t2_String_val_topology_PartitionBuilder_val without initialising it. */
t2_String_val_topology_PartitionBuilder_val* t2_String_val_topology_PartitionBuilder_val_Alloc();

/* Allocate a pony_CPPStateChangeBuilder without initialising it. */
pony_CPPStateChangeBuilder* pony_CPPStateChangeBuilder_Alloc();

/* Allocate a buffered_Reader without initialising it. */
buffered_Reader* buffered_Reader_Alloc();

/* Allocate a collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_box without initialising it. */
collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_box* collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a options_F64Argument without initialising it. */
options_F64Argument* options_F64Argument_Alloc();

/* Allocate a Array_u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_ComputationRunnerBuilder_pony_CPPData_val_pony_CPPData_val without initialising it. */
topology_ComputationRunnerBuilder_pony_CPPData_val_pony_CPPData_val* topology_ComputationRunnerBuilder_pony_CPPData_val_pony_CPPData_val_Alloc();

/* Allocate a messages_ChannelMsgDecoder without initialising it. */
messages_ChannelMsgDecoder* messages_ChannelMsgDecoder_Alloc();

/* Allocate a collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_box without initialising it. */
collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_box* collections_MapValues_String_val_String_val_collections_HashIs_String_val_val_collections_HashMap_String_val_String_val_collections_HashIs_String_val_val_box_Alloc();

/* Allocate a ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_ref without initialising it. */
ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_ref* ArrayValues_tcp_sink_TCPSink_tag_Array_tcp_sink_TCPSink_tag_ref_Alloc();

/* Allocate a files_FileExists without initialising it. */
files_FileExists* files_FileExists_Alloc();

/* Allocate a u2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_None_val without initialising it. */
u2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_None_val* u2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_None_val_Alloc();

/* Allocate a collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_ref without initialising it. */
collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_ref* collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_ref_Alloc();

/* Allocate a network_$33$33 without initialising it. */
network_$33$33* network_$33$33_Alloc();

/* Allocate a collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_box without initialising it. */
collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_box* collections_MapValues_U128_val_String_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_box_Alloc();

/* Allocate a collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_box without initialising it. */
collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_box* collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a messages_ForwardMsg_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val without initialising it. */
messages_ForwardMsg_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val* messages_ForwardMsg_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val_Alloc();

/* Allocate a u2_None_val_pony_CPPData_val without initialising it. */
u2_None_val_pony_CPPData_val* u2_None_val_pony_CPPData_val_Alloc();

/* Allocate a network_JoiningControlSenderConnectNotifier without initialising it. */
network_JoiningControlSenderConnectNotifier* network_JoiningControlSenderConnectNotifier_Alloc();

/* Allocate a topology_$36$135_U8_val without initialising it. */
topology_$36$135_U8_val* topology_$36$135_U8_val_Alloc();

/* Allocate a Array_u3_t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a tcp_source_SourceBuilder without initialising it. */
tcp_source_SourceBuilder* tcp_source_SourceBuilder_Alloc();

/* Allocate a messages_AckDataConnectMsg without initialising it. */
messages_AckDataConnectMsg* messages_AckDataConnectMsg_Alloc();

/* Allocate a collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_val without initialising it. */
collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_val* collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a Array_u3_t2_topology_Initializable_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_topology_Initializable_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_topology_Initializable_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_RouterRegistry without initialising it. */
topology_RouterRegistry* topology_RouterRegistry_Alloc();

/* Allocate a u2_Greater_val_Less_val without initialising it. */
u2_Greater_val_Less_val* u2_Greater_val_Less_val_Alloc();

/* Allocate a topology_StateRunner_pony_CPPState_ref without initialising it. */
topology_StateRunner_pony_CPPState_ref* topology_StateRunner_pony_CPPState_ref_Alloc();

/* Allocate a t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box without initialising it. */
t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box* t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_Alloc();

/* Allocate a options_Options without initialising it. */
options_Options* options_Options_Alloc();

/* Allocate a topology_$36$118 without initialising it. */
topology_$36$118* topology_$36$118_Alloc();

/* Allocate a Array_net_TCPListener_tag without initialising it. */
Array_net_TCPListener_tag* Array_net_TCPListener_tag_Alloc();

/* Allocate a ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_val without initialising it. */
ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_val* ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_val_Alloc();

/* Allocate a ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_box without initialising it. */
ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_box* ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_box_Alloc();

/* Allocate a u2_String_val_None_val without initialising it. */
u2_String_val_None_val* u2_String_val_None_val_Alloc();

/* Allocate a u2_net_TCPListener_tag_data_channel_DataChannelListener_tag without initialising it. */
u2_net_TCPListener_tag_data_channel_DataChannelListener_tag* u2_net_TCPListener_tag_data_channel_DataChannelListener_tag_Alloc();

/* Allocate a files_Path without initialising it. */
files_Path* files_Path_Alloc();

/* Allocate a files_FileInfo without initialising it. */
files_FileInfo* files_FileInfo_Alloc();

/* Allocate a u3_t2_U64_val_routing__Route_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U64_val_routing__Route_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U64_val_routing__Route_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a boundary_$10$28 without initialising it. */
boundary_$10$28* boundary_$10$28_Alloc();

/* Allocate a topology_$36$123_pony_CPPKey_val without initialising it. */
topology_$36$123_pony_CPPKey_val* topology_$36$123_pony_CPPKey_val_Alloc();

/* Allocate a ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_val without initialising it. */
ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_val* ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_val_Alloc();

/* Allocate a t2_boundary__BoundaryId_box_boundary_DataReceiver_tag without initialising it. */
t2_boundary__BoundaryId_box_boundary_DataReceiver_tag* t2_boundary__BoundaryId_box_boundary_DataReceiver_tag_Alloc();

/* Allocate a collections_HashIs_boundary_DataReceiversSubscriber_tag without initialising it. */
collections_HashIs_boundary_DataReceiversSubscriber_tag* collections_HashIs_boundary_DataReceiversSubscriber_tag_Alloc();

/* Allocate a collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_box without initialising it. */
collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_box* collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_box_Alloc();

/* Allocate a u3_t2_routing_RouteLogic_val_routing_RouteLogic_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_routing_RouteLogic_val_routing_RouteLogic_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_routing_RouteLogic_val_routing_RouteLogic_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a pony_CPPApplicationBuilder without initialising it. */
pony_CPPApplicationBuilder* pony_CPPApplicationBuilder_Alloc();

pony_CPPApplicationBuilder* pony_CPPApplicationBuilder_create(pony_CPPApplicationBuilder* self);

None* pony_CPPApplicationBuilder_to_state_partition(pony_CPPApplicationBuilder* self, char* state_computation_, char* state_builder_, char* state_name_, char* partition_, bool multi_worker);

None* pony_CPPApplicationBuilder_to_stateful(pony_CPPApplicationBuilder* self, char* state_computation, char* state_builder_, char* state_name_);

None* pony_CPPApplicationBuilder_done(pony_CPPApplicationBuilder* self);

None* pony_CPPApplicationBuilder_to_sink(pony_CPPApplicationBuilder* self, char* sink_encoder_);

None* pony_CPPApplicationBuilder_to(pony_CPPApplicationBuilder* self, char* computation_builder_);

None* pony_CPPApplicationBuilder_create_application(pony_CPPApplicationBuilder* self, char* application_name_);

None* pony_CPPApplicationBuilder_new_pipeline(pony_CPPApplicationBuilder* self, char* name_, char* source_decoder_);

None* pony_CPPApplicationBuilder_to_state_partition_u64(pony_CPPApplicationBuilder* self, char* state_computation_, char* state_builder_, char* state_name_, char* partition_, bool multi_worker);

/* Allocate a t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref without initialising it. */
t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref* t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_Alloc();

/* Allocate a collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_ref* collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val without initialising it. */
dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val* dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_Alloc();

/* Allocate a files__EACCES without initialising it. */
files__EACCES* files__EACCES_Alloc();

/* Allocate a metrics_PauseBeforeReconnect without initialising it. */
metrics_PauseBeforeReconnect* metrics_PauseBeforeReconnect_Alloc();

/* Allocate a ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_val without initialising it. */
ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_val* ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_val_Alloc();

/* Allocate a t2_pony_CPPKey_val_topology_ProxyAddress_val without initialising it. */
t2_pony_CPPKey_val_topology_ProxyAddress_val* t2_pony_CPPKey_val_topology_ProxyAddress_val_Alloc();

/* Allocate a collections_HashSet_data_channel_DataChannelListener_tag_collections_HashIs_data_channel_DataChannelListener_tag_val without initialising it. */
collections_HashSet_data_channel_DataChannelListener_tag_collections_HashIs_data_channel_DataChannelListener_tag_val* collections_HashSet_data_channel_DataChannelListener_tag_collections_HashIs_data_channel_DataChannelListener_tag_val_Alloc();

/* Allocate a collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_val without initialising it. */
collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_val* collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a messages_UnmuteRequestMsg without initialising it. */
messages_UnmuteRequestMsg* messages_UnmuteRequestMsg_Alloc();

/* Allocate a collections_HashIs_routing_Consumer_tag without initialising it. */
collections_HashIs_routing_Consumer_tag* collections_HashIs_routing_Consumer_tag_Alloc();

/* Allocate a collections_HashIs_routing_RouteLogic_ref without initialising it. */
collections_HashIs_routing_RouteLogic_ref* collections_HashIs_routing_RouteLogic_ref_Alloc();

/* Allocate a t2_String_val_String_iso without initialising it. */
t2_String_val_String_iso* t2_String_val_String_iso_Alloc();

/* Allocate a boundary__DataReceiverNotProcessingPhase without initialising it. */
boundary__DataReceiverNotProcessingPhase* boundary__DataReceiverNotProcessingPhase_Alloc();

/* Allocate a u2_String_val_Array_String_val_val without initialising it. */
u2_String_val_Array_String_val_val* u2_String_val_Array_String_val_val_Alloc();

/* Allocate a options_InvalidArgument without initialising it. */
options_InvalidArgument* options_InvalidArgument_Alloc();

/* Allocate a t2_String_val_topology_StateSubpartition_val without initialising it. */
t2_String_val_topology_StateSubpartition_val* t2_String_val_topology_StateSubpartition_val_Alloc();

/* Allocate a boundary_$10$23 without initialising it. */
boundary_$10$23* boundary_$10$23_Alloc();

/* Allocate a messages1_ExternalReadyMsg without initialising it. */
messages1_ExternalReadyMsg* messages1_ExternalReadyMsg_Alloc();

/* Allocate a t2_u2_pony_CPPData_val_None_val_u2_pony_CPPStateChange_ref_None_val without initialising it. */
t2_u2_pony_CPPData_val_None_val_u2_pony_CPPStateChange_ref_None_val* t2_u2_pony_CPPData_val_None_val_u2_pony_CPPStateChange_ref_None_val_Alloc();

/* Allocate a messages_ReplayableDeliveryMsg without initialising it. */
messages_ReplayableDeliveryMsg* messages_ReplayableDeliveryMsg_Alloc();

/* Allocate a u2_U128_val_None_val without initialising it. */
u2_U128_val_None_val* u2_U128_val_None_val_Alloc();

/* Allocate a routing__OutgoingToIncoming without initialising it. */
routing__OutgoingToIncoming* routing__OutgoingToIncoming_Alloc();

/* Allocate a t2_String_val_USize_val without initialising it. */
t2_String_val_USize_val* t2_String_val_USize_val_Alloc();

/* Allocate a files_FileBadFileNumber without initialising it. */
files_FileBadFileNumber* files_FileBadFileNumber_Alloc();

/* Allocate a Array_u3_t2_String_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a initialization_$15$64 without initialising it. */
initialization_$15$64* initialization_$15$64_Alloc();

/* Allocate a u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box without initialising it. */
Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box* Iterator_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_box_Alloc();

/* Allocate a Array_u3_t2_http__HostService_val_http__ClientConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_http__HostService_val_http__ClientConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_http__HostService_val_http__ClientConnection_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_box without initialising it. */
ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_box* ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_box_Alloc();

/* Allocate a routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_pony_CPPData_val without initialising it. */
routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_pony_CPPData_val* routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_pony_CPPData_val_Alloc();

/* Allocate a ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_box without initialising it. */
ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_box* ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_box_Alloc();

/* Allocate a u2_topology_RunnerBuilder_val_None_val without initialising it. */
u2_topology_RunnerBuilder_val_None_val* u2_topology_RunnerBuilder_val_None_val_Alloc();

/* Allocate a u3_t2_U128_val_u2_topology_ProxyAddress_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U128_val_u2_topology_ProxyAddress_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U128_val_u2_topology_ProxyAddress_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a wallaroo_PipelineBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val without initialising it. */
wallaroo_PipelineBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val* wallaroo_PipelineBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_Alloc();

/* Allocate a collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_val without initialising it. */
collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_val* collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_val_Alloc();

/* Allocate a ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_ref without initialising it. */
ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_ref* ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_ref_Alloc();

/* Allocate a initialization_$15$50 without initialising it. */
initialization_$15$50* initialization_$15$50_Alloc();

/* Allocate a t2_U128_val_topology_StepBuilder_val without initialising it. */
t2_U128_val_topology_StepBuilder_val* t2_U128_val_topology_StepBuilder_val_Alloc();

/* Allocate a ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_val without initialising it. */
ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_val* ArrayValues_wallaroo_BasicPipeline_ref_Array_wallaroo_BasicPipeline_ref_val_Alloc();

/* Allocate a tcp_source_TCPSourceNotify without initialising it. */
tcp_source_TCPSourceNotify* tcp_source_TCPSourceNotify_Alloc();

/* Allocate a Array_data_channel_DataChannelListener_tag without initialising it. */
Array_data_channel_DataChannelListener_tag* Array_data_channel_DataChannelListener_tag_Alloc();

/* Allocate a collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val* collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a collections_HashSet_net_TCPListener_tag_collections_HashIs_net_TCPListener_tag_val without initialising it. */
collections_HashSet_net_TCPListener_tag_collections_HashIs_net_TCPListener_tag_val* collections_HashSet_net_TCPListener_tag_collections_HashIs_net_TCPListener_tag_val_Alloc();

/* Allocate a ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_ref without initialising it. */
ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_ref* ArrayValues_t2_U8_val_USize_val_Array_t2_U8_val_USize_val_ref_Alloc();

/* Allocate a t2_U128_val_u2_topology_ProxyAddress_val_U128_val without initialising it. */
t2_U128_val_u2_topology_ProxyAddress_val_U128_val* t2_U128_val_u2_topology_ProxyAddress_val_U128_val_Alloc();

/* Allocate a routing__EmptyRouteLogic without initialising it. */
routing__EmptyRouteLogic* routing__EmptyRouteLogic_Alloc();

/* Allocate a files__EEXIST without initialising it. */
files__EEXIST* files__EEXIST_Alloc();

/* Allocate a topology_$36$119_pony_CPPKey_val without initialising it. */
topology_$36$119_pony_CPPKey_val* topology_$36$119_pony_CPPKey_val_Alloc();

/* Allocate a Any without initialising it. */
Any* Any_Alloc();

/* Allocate a network_$33$38 without initialising it. */
network_$33$38* network_$33$38_Alloc();

/* Allocate a u2_t2_String_val_String_val_None_val without initialising it. */
u2_t2_String_val_String_val_None_val* u2_t2_String_val_String_val_None_val_Alloc();

/* Allocate a $0$1_routing_Producer_tag without initialising it. */
$0$1_routing_Producer_tag* $0$1_routing_Producer_tag_Alloc();

/* Allocate a routing_Route without initialising it. */
routing_Route* routing_Route_Alloc();

/* Allocate a u3_t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a boundary_$10$15_U64_val without initialising it. */
boundary_$10$15_U64_val* boundary_$10$15_U64_val_Alloc();

/* Allocate a initialization_$15$69 without initialising it. */
initialization_$15$69* initialization_$15$69_Alloc();

/* Allocate a net_TCPListener without initialising it. */
net_TCPListener* net_TCPListener_Alloc();

/* Allocate a u2_initialization_LocalTopologyInitializer_tag_None_val without initialising it. */
u2_initialization_LocalTopologyInitializer_tag_None_val* u2_initialization_LocalTopologyInitializer_tag_None_val_Alloc();

/* Allocate a tcp_sink_PauseBeforeReconnectTCPSink without initialising it. */
tcp_sink_PauseBeforeReconnectTCPSink* tcp_sink_PauseBeforeReconnectTCPSink_Alloc();

/* Allocate a options_MissingArgument without initialising it. */
options_MissingArgument* options_MissingArgument_Alloc();

/* Allocate a topology_StateBuilder_pony_CPPState_ref without initialising it. */
topology_StateBuilder_pony_CPPState_ref* topology_StateBuilder_pony_CPPState_ref_Alloc();

/* Allocate a topology_ReplayableRunner without initialising it. */
topology_ReplayableRunner* topology_ReplayableRunner_Alloc();

/* Allocate a t2_String_val_net_TCPConnection_tag without initialising it. */
t2_String_val_net_TCPConnection_tag* t2_String_val_net_TCPConnection_tag_Alloc();

/* Allocate a recovery_$37$17 without initialising it. */
recovery_$37$17* recovery_$37$17_Alloc();

/* Allocate a u3_t2_String_val_USize_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_USize_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_USize_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u3_t2_topology_Step_tag_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_topology_Step_tag_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_topology_Step_tag_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a messages_JoiningWorkerInitializedMsg without initialising it. */
messages_JoiningWorkerInitializedMsg* messages_JoiningWorkerInitializedMsg_Alloc();

/* Allocate a collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_val without initialising it. */
collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_val* collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a Array_u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a files_FileMkdir without initialising it. */
files_FileMkdir* files_FileMkdir_Alloc();

/* Allocate a messages1__Start without initialising it. */
messages1__Start* messages1__Start_Alloc();

/* Allocate a messages_ForwardMsg_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
messages_ForwardMsg_topology_StateProcessor_pony_CPPState_ref_val* messages_ForwardMsg_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a tcp_source_TypedSourceBuilderBuilder_pony_CPPData_val without initialising it. */
tcp_source_TypedSourceBuilderBuilder_pony_CPPData_val* tcp_source_TypedSourceBuilderBuilder_pony_CPPData_val_Alloc();

/* Allocate a wallaroo_StartupHelp without initialising it. */
wallaroo_StartupHelp* wallaroo_StartupHelp_Alloc();

/* Allocate a Array_topology_StateChangeBuilder_pony_CPPState_ref_val without initialising it. */
Array_topology_StateChangeBuilder_pony_CPPState_ref_val* Array_topology_StateChangeBuilder_pony_CPPState_ref_val_Alloc();

/* Allocate a ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_val without initialising it. */
ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_val* ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_val_Alloc();

/* Allocate a messages1_ExternalMsgDecoder without initialising it. */
messages1_ExternalMsgDecoder* messages1_ExternalMsgDecoder_Alloc();

/* Allocate a recovery__LogReplay without initialising it. */
recovery__LogReplay* recovery__LogReplay_Alloc();

/* Allocate a routing_$35$76_pony_CPPData_val without initialising it. */
routing_$35$76_pony_CPPData_val* routing_$35$76_pony_CPPData_val_Alloc();

/* Allocate a wallaroo_$19$30 without initialising it. */
wallaroo_$19$30* wallaroo_$19$30_Alloc();

/* Allocate a u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val without initialising it. */
collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val* collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_Alloc();

/* Allocate a ArrayValues_String_ref_Array_String_ref_val without initialising it. */
ArrayValues_String_ref_Array_String_ref_val* ArrayValues_String_ref_Array_String_ref_val_Alloc();

/* Allocate a collections_ListNode_t2_Array_U8_val_val_USize_val without initialising it. */
collections_ListNode_t2_Array_U8_val_val_USize_val* collections_ListNode_t2_Array_U8_val_val_USize_val_Alloc();

/* Allocate a u3_t2_U64_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U64_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U64_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_boundary_OutgoingBoundaryBuilder_val_None_val without initialising it. */
u2_boundary_OutgoingBoundaryBuilder_val_None_val* u2_boundary_OutgoingBoundaryBuilder_val_None_val_Alloc();

/* Allocate a u2_network_Connections_tag_None_val without initialising it. */
u2_network_Connections_tag_None_val* u2_network_Connections_tag_None_val_Alloc();

/* Allocate a collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_val without initialising it. */
collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_val* collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_val_Alloc();

/* Allocate a t6_Bool_val_Bool_val_u2_topology_StateChange_pony_CPPState_ref_ref_None_val_U64_val_U64_val_U64_val without initialising it. */
t6_Bool_val_Bool_val_u2_topology_StateChange_pony_CPPState_ref_ref_None_val_U64_val_U64_val_U64_val* t6_Bool_val_Bool_val_u2_topology_StateChange_pony_CPPState_ref_ref_None_val_U64_val_U64_val_U64_val_Alloc();

/* Allocate a ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_ref without initialising it. */
ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_ref* ArrayValues_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_ref_Alloc();

/* Allocate a t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val without initialising it. */
t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val* t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_Alloc();

/* Allocate a t2_String_val_t2_String_val_String_val without initialising it. */
t2_String_val_t2_String_val_String_val* t2_String_val_t2_String_val_String_val_Alloc();

/* Allocate a routing_$35$96_pony_CPPData_val without initialising it. */
routing_$35$96_pony_CPPData_val* routing_$35$96_pony_CPPData_val_Alloc();

/* Allocate a files_FilePath without initialising it. */
files_FilePath* files_FilePath_Alloc();

/* Allocate a u2_Array_U64_val_val_None_val without initialising it. */
u2_Array_U64_val_val_None_val* u2_Array_U64_val_val_None_val_Alloc();

/* Allocate a collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref* collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a recovery__RecoveryPhase without initialising it. */
recovery__RecoveryPhase* recovery__RecoveryPhase_Alloc();

/* Allocate a t2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val without initialising it. */
t2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val* t2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val_Alloc();

/* Allocate a topology_KeyedPartitionAddresses_U8_val without initialising it. */
topology_KeyedPartitionAddresses_U8_val* topology_KeyedPartitionAddresses_U8_val_Alloc();

/* Allocate a t2_U128_val_U128_val without initialising it. */
t2_U128_val_U128_val* t2_U128_val_U128_val_Alloc();

/* Allocate a network_$33$28 without initialising it. */
network_$33$28* network_$33$28_Alloc();

/* Allocate a fix_generator_utils_RandomNumberGenerator without initialising it. */
fix_generator_utils_RandomNumberGenerator* fix_generator_utils_RandomNumberGenerator_Alloc();

/* Allocate a ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_val without initialising it. */
ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_val* ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_val_Alloc();

/* Allocate a collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_box without initialising it. */
collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_box* collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_box_Alloc();

/* Allocate a u2_Array_topology_RunnerBuilder_val_val_None_val without initialising it. */
u2_Array_topology_RunnerBuilder_val_val_None_val* u2_Array_topology_RunnerBuilder_val_val_None_val_Alloc();

/* Allocate a collections_HashMap_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections_HashEq_String_val_val* collections_HashMap_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections_HashEq_String_val_val_Alloc();

/* Allocate a ssl_SSLContext without initialising it. */
ssl_SSLContext* ssl_SSLContext_Alloc();

/* Allocate a files_FileStat without initialising it. */
files_FileStat* files_FileStat_Alloc();

/* Allocate a t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag without initialising it. */
t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag* t2_U128_val_i2_recovery_Resilient_tag_routing_Producer_tag_Alloc();

/* Allocate a initialization_$15$72 without initialising it. */
initialization_$15$72* initialization_$15$72_Alloc();

/* Allocate a topology_EmptyRouter without initialising it. */
topology_EmptyRouter* topology_EmptyRouter_Alloc();

/* Allocate a collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_box without initialising it. */
collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_box* collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_box_Alloc();

/* Allocate a ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_val without initialising it. */
ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_val* ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_val_Alloc();

/* Allocate a wallaroo_Pipeline_pony_CPPData_val_pony_CPPData_val without initialising it. */
wallaroo_Pipeline_pony_CPPData_val_pony_CPPData_val* wallaroo_Pipeline_pony_CPPData_val_pony_CPPData_val_Alloc();

/* Allocate a routing_$35$74_pony_CPPData_val_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
routing_$35$74_pony_CPPData_val_topology_StateProcessor_pony_CPPState_ref_val* routing_$35$74_pony_CPPData_val_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_box without initialising it. */
ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_box* ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_box_Alloc();

/* Allocate a data_channel_DataChannelConnectNotifier without initialising it. */
data_channel_DataChannelConnectNotifier* data_channel_DataChannelConnectNotifier_Alloc();

/* Allocate a Array_u3_t2_pony_CPPKey_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_pony_CPPKey_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_pony_CPPKey_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_ref* collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a collections_HashMap_Any_tag_Any_tag_collections_HashIs_Any_tag_val without initialising it. */
collections_HashMap_Any_tag_Any_tag_collections_HashIs_Any_tag_val* collections_HashMap_Any_tag_Any_tag_collections_HashIs_Any_tag_val_Alloc();

/* Allocate a collection_helpers_SetHelpers_String_val without initialising it. */
collection_helpers_SetHelpers_String_val* collection_helpers_SetHelpers_String_val_Alloc();

/* Allocate a ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_ref without initialising it. */
ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_ref* ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_ref_Alloc();

/* Allocate a network_$33$39 without initialising it. */
network_$33$39* network_$33$39_Alloc();

/* Allocate a ArrayValues_String_ref_Array_String_ref_box without initialising it. */
ArrayValues_String_ref_Array_String_ref_box* ArrayValues_String_ref_Array_String_ref_box_Alloc();

/* Allocate a t2_String_val_I64_val without initialising it. */
t2_String_val_I64_val* t2_String_val_I64_val_Alloc();

/* Allocate a Array_topology_StateChange_pony_CPPState_ref_ref without initialising it. */
Array_topology_StateChange_pony_CPPState_ref_ref* Array_topology_StateChange_pony_CPPState_ref_ref_Alloc();

/* Allocate a messages1__GilesSendersStarted without initialising it. */
messages1__GilesSendersStarted* messages1__GilesSendersStarted_Alloc();

/* Allocate a topology_StateChangeRepository_pony_CPPState_ref without initialising it. */
topology_StateChangeRepository_pony_CPPState_ref* topology_StateChangeRepository_pony_CPPState_ref_Alloc();

/* Allocate a collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_val without initialising it. */
collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_val* collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_val_Alloc();

/* Allocate a Iterator_u2_String_val_Array_U8_val_val without initialising it. */
Iterator_u2_String_val_Array_U8_val_val* Iterator_u2_String_val_Array_U8_val_val_Alloc();

/* Allocate a network_WallarooOutgoingNetworkActorNotify without initialising it. */
network_WallarooOutgoingNetworkActorNotify* network_WallarooOutgoingNetworkActorNotify_Alloc();

/* Allocate a u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a Array_u3_t2_net_TCPListener_tag_net_TCPListener_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_net_TCPListener_tag_net_TCPListener_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_net_TCPListener_tag_net_TCPListener_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_Initializable without initialising it. */
topology_Initializable* topology_Initializable_Alloc();

/* Allocate a Array_String_val without initialising it. */
Array_String_val* Array_String_val_Alloc();

/* Allocate a collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_val without initialising it. */
collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_val* collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a pony_CPPKey without initialising it. */
pony_CPPKey* pony_CPPKey_Alloc();

/* Allocate a t2_None_val_collections_ListNode_t2_Array_U8_val_val_USize_val_ref without initialising it. */
t2_None_val_collections_ListNode_t2_Array_U8_val_val_USize_val_ref* t2_None_val_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_Alloc();

/* Allocate a t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_iso_U64_val_U64_val_String_val_String_val without initialising it. */
t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_iso_U64_val_U64_val_String_val_String_val* t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_iso_U64_val_U64_val_String_val_String_val_Alloc();

/* Allocate a recovery_$37$13 without initialising it. */
recovery_$37$13* recovery_$37$13_Alloc();

/* Allocate a collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_box without initialising it. */
collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_box* collections_MapPairs_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_StateSubpartition_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a wallaroo_Startup without initialising it. */
wallaroo_Startup* wallaroo_Startup_Alloc();

/* Allocate a ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_box without initialising it. */
ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_box* ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_box_Alloc();

/* Allocate a t2_ISize_val_Bool_val without initialising it. */
t2_ISize_val_Bool_val* t2_ISize_val_Bool_val_Alloc();

/* Allocate a tcp_source_$40$10 without initialising it. */
tcp_source_$40$10* tcp_source_$40$10_Alloc();

/* Allocate a t2_u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val_u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val without initialising it. */
t2_u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val_u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val* t2_u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val_u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val_Alloc();

/* Allocate a collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_val without initialising it. */
collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_val* collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_val_Alloc();

/* Allocate a Array_String_ref without initialising it. */
Array_String_ref* Array_String_ref_Alloc();

/* Allocate a wallaroo_$19$28 without initialising it. */
wallaroo_$19$28* wallaroo_$19$28_Alloc();

/* Allocate a recovery_$37$26 without initialising it. */
recovery_$37$26* recovery_$37$26_Alloc();

/* Allocate a collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val without initialising it. */
collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val* collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_Alloc();

/* Allocate a collections_HashSet_U128_val_collections_HashIs_U128_val_val without initialising it. */
collections_HashSet_U128_val_collections_HashIs_U128_val_val* collections_HashSet_U128_val_collections_HashIs_U128_val_val_Alloc();

/* Allocate a u2_Array_String_val_val_topology_ProxyAddress_val without initialising it. */
u2_Array_String_val_val_topology_ProxyAddress_val* u2_Array_String_val_val_topology_ProxyAddress_val_Alloc();

/* Allocate a ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_ref without initialising it. */
ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_ref* ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_ref_Alloc();

/* Allocate a invariant_Invariant without initialising it. */
invariant_Invariant* invariant_Invariant_Alloc();

/* Allocate a $0$13_String_val without initialising it. */
$0$13_String_val* $0$13_String_val_Alloc();

/* Allocate a collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_val without initialising it. */
collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_val* collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_val_Alloc();

/* Allocate a ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_val without initialising it. */
ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_val* ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_val_Alloc();

/* Allocate a topology_$36$84_pony_CPPState_ref without initialising it. */
topology_$36$84_pony_CPPState_ref* topology_$36$84_pony_CPPState_ref_Alloc();

/* Allocate a routing_$35$74_pony_CPPData_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val without initialising it. */
routing_$35$74_pony_CPPData_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val* routing_$35$74_pony_CPPData_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val_Alloc();

/* Allocate a topology_$36$114_pony_CPPData_val_pony_CPPKey_val without initialising it. */
topology_$36$114_pony_CPPData_val_pony_CPPKey_val* topology_$36$114_pony_CPPData_val_pony_CPPKey_val_Alloc();

/* Allocate a ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_ref without initialising it. */
ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_ref* ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_ref_Alloc();

/* Allocate a options_Required without initialising it. */
options_Required* options_Required_Alloc();

/* Allocate a collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_box without initialising it. */
collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_box* collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a u3_t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a boundary_$10$25 without initialising it. */
boundary_$10$25* boundary_$10$25_Alloc();

/* Allocate a collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_box without initialising it. */
collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_box* collections_MapPairs_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref* collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a topology_AugmentablePartitionRouter_U8_val without initialising it. */
topology_AugmentablePartitionRouter_U8_val* topology_AugmentablePartitionRouter_U8_val_Alloc();

/* Allocate a Array_t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_val_U64_val_U64_val_String_val_String_val without initialising it. */
Array_t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_val_U64_val_U64_val_String_val_String_val* Array_t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_val_U64_val_U64_val_String_val_String_val_Alloc();

/* Allocate a u2_topology_DirectRouter_val_None_val without initialising it. */
u2_topology_DirectRouter_val_None_val* u2_topology_DirectRouter_val_None_val_Alloc();

/* Allocate a u2_topology_Runner_iso_None_val without initialising it. */
u2_topology_Runner_iso_None_val* u2_topology_Runner_iso_None_val_Alloc();

/* Allocate a tcp_source_TCPSourceListenerBuilder without initialising it. */
tcp_source_TCPSourceListenerBuilder* tcp_source_TCPSourceListenerBuilder_Alloc();

/* Allocate a t2_String_val_metrics__MetricsReporter_val without initialising it. */
t2_String_val_metrics__MetricsReporter_val* t2_String_val_metrics__MetricsReporter_val_Alloc();

/* Allocate a u2_boundary_DataReceiversSubscriber_tag_None_val without initialising it. */
u2_boundary_DataReceiversSubscriber_tag_None_val* u2_boundary_DataReceiversSubscriber_tag_None_val_Alloc();

/* Allocate a recovery_$37$22 without initialising it. */
recovery_$37$22* recovery_$37$22_Alloc();

/* Allocate a u2_boundary_OutgoingBoundary_tag_None_val without initialising it. */
u2_boundary_OutgoingBoundary_tag_None_val* u2_boundary_OutgoingBoundary_tag_None_val_Alloc();

/* Allocate a u2_Array_U64_val_ref_None_val without initialising it. */
u2_Array_U64_val_ref_None_val* u2_Array_U64_val_ref_None_val_Alloc();

/* Allocate a t3_Bool_val_Bool_val_U64_val without initialising it. */
t3_Bool_val_Bool_val_U64_val* t3_Bool_val_Bool_val_U64_val_Alloc();

/* Allocate a Array_u3_t2_U128_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U128_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U128_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_HashMap_net_TCPListener_tag_net_TCPListener_tag_collections_HashIs_net_TCPListener_tag_val without initialising it. */
collections_HashMap_net_TCPListener_tag_net_TCPListener_tag_collections_HashIs_net_TCPListener_tag_val* collections_HashMap_net_TCPListener_tag_net_TCPListener_tag_collections_HashIs_net_TCPListener_tag_val_Alloc();

/* Allocate a collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_val without initialising it. */
collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_val* collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_val_Alloc();

/* Allocate a t2_time_Timer_tag_time_Timer_box without initialising it. */
t2_time_Timer_tag_time_Timer_box* t2_time_Timer_tag_time_Timer_box_Alloc();

/* Allocate a boundary_OutgoingBoundary without initialising it. */
boundary_OutgoingBoundary* boundary_OutgoingBoundary_Alloc();

/* Allocate a ArrayValues_U64_val_Array_U64_val_ref without initialising it. */
ArrayValues_U64_val_Array_U64_val_ref* ArrayValues_U64_val_Array_U64_val_ref_Alloc();

/* Allocate a u2_initialization_LocalTopology_val_None_val without initialising it. */
u2_initialization_LocalTopology_val_None_val* u2_initialization_LocalTopology_val_None_val_Alloc();

/* Allocate a topology_$36$123_U64_val without initialising it. */
topology_$36$123_U64_val* topology_$36$123_U64_val_Alloc();

/* Allocate a collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_box without initialising it. */
collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_box* collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_pony_CPPKey_val_pony_CPPState_ref without initialising it. */
topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_pony_CPPKey_val_pony_CPPState_ref* topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_pony_CPPKey_val_pony_CPPState_ref_Alloc();

/* Allocate a u3_t2_String_val_boundary_OutgoingBoundaryBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_boundary_OutgoingBoundaryBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_boundary_OutgoingBoundaryBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u3_t2_time_Timer_tag_time_Timer_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_time_Timer_tag_time_Timer_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_time_Timer_tag_time_Timer_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val* collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a topology_StepBuilder without initialising it. */
topology_StepBuilder* topology_StepBuilder_Alloc();

/* Allocate a cluster_manager_ClusterManager without initialising it. */
cluster_manager_ClusterManager* cluster_manager_ClusterManager_Alloc();

/* Allocate a collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_ref without initialising it. */
collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_ref* collections_MapPairs_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_ref_Alloc();

/* Allocate a collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_box without initialising it. */
collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_box* collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_box_Alloc();

/* Allocate a hub_HubMsgTypes without initialising it. */
hub_HubMsgTypes* hub_HubMsgTypes_Alloc();

/* Allocate a dag_Named without initialising it. */
dag_Named* dag_Named_Alloc();

/* Allocate a collections_HashIs_tcp_source_TCPSourceListener_tag without initialising it. */
collections_HashIs_tcp_source_TCPSourceListener_tag* collections_HashIs_tcp_source_TCPSourceListener_tag_Alloc();

/* Allocate a bytes_Bytes without initialising it. */
bytes_Bytes* bytes_Bytes_Alloc();

/* Allocate a ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_box without initialising it. */
ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_box* ArrayValues_t2_U64_val_USize_val_Array_t2_U64_val_USize_val_box_Alloc();

/* Allocate a network_HomeConnectNotify without initialising it. */
network_HomeConnectNotify* network_HomeConnectNotify_Alloc();

/* Allocate a Array_Array_String_val_ref without initialising it. */
Array_Array_String_val_ref* Array_Array_String_val_ref_Alloc();

/* Allocate a topology_KeyedStateSubpartition_pony_CPPData_val_pony_CPPKey_val without initialising it. */
topology_KeyedStateSubpartition_pony_CPPData_val_pony_CPPKey_val* topology_KeyedStateSubpartition_pony_CPPData_val_pony_CPPKey_val_Alloc();

/* Allocate a ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_box without initialising it. */
ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_box* ArrayValues_routing_Producer_tag_Array_routing_Producer_tag_box_Alloc();

/* Allocate a topology_PartitionAddresses without initialising it. */
topology_PartitionAddresses* topology_PartitionAddresses_Alloc();

/* Allocate a u2_wallaroo_InitFile_val_None_val without initialising it. */
u2_wallaroo_InitFile_val_None_val* u2_wallaroo_InitFile_val_None_val_Alloc();

/* Allocate a topology_$36$100_pony_CPPData_val without initialising it. */
topology_$36$100_pony_CPPData_val* topology_$36$100_pony_CPPData_val_Alloc();

/* Allocate a ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_ref without initialising it. */
ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_ref* ArrayValues_net_TCPListener_tag_Array_net_TCPListener_tag_ref_Alloc();

/* Allocate a Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag without initialising it. */
Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag* Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Alloc();

/* Allocate a Array_options__Option_ref without initialising it. */
Array_options__Option_ref* Array_options__Option_ref_Alloc();

/* Allocate a Array_u3_t2_pony_CPPKey_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_pony_CPPKey_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_pony_CPPKey_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a Array_u3_t2_String_val_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_options_Required_val_options_Optional_val without initialising it. */
u2_options_Required_val_options_Optional_val* u2_options_Required_val_options_Optional_val_Alloc();

/* Allocate a t2_U128_val_topology_Step_tag without initialising it. */
t2_U128_val_topology_Step_tag* t2_U128_val_topology_Step_tag_Alloc();

/* Allocate a pony_$2$7 without initialising it. */
pony_$2$7* pony_$2$7_Alloc();

/* Allocate a t2_routing_RouteLogic_val_routing_RouteLogic_val without initialising it. */
t2_routing_RouteLogic_val_routing_RouteLogic_val* t2_routing_RouteLogic_val_routing_RouteLogic_val_Alloc();

/* Allocate a recovery__ReplayPhase without initialising it. */
recovery__ReplayPhase* recovery__ReplayPhase_Alloc();

/* Allocate a Equal without initialising it. */
Equal* Equal_Alloc();

/* Allocate a metrics_NodeIngressEgressCategory without initialising it. */
metrics_NodeIngressEgressCategory* metrics_NodeIngressEgressCategory_Alloc();

/* Allocate a t2_topology_Initializable_tag_topology_Initializable_tag without initialising it. */
t2_topology_Initializable_tag_topology_Initializable_tag* t2_topology_Initializable_tag_topology_Initializable_tag_Alloc();

/* Allocate a routing_$35$97 without initialising it. */
routing_$35$97* routing_$35$97_Alloc();

/* Allocate a ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_ref without initialising it. */
ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_ref* ArrayValues_topology_StateChangeBuilder_pony_CPPState_ref_val_Array_topology_StateChangeBuilder_pony_CPPState_ref_val_ref_Alloc();

/* Allocate a messages1_ExternalGilesSendersStartedMsg without initialising it. */
messages1_ExternalGilesSendersStartedMsg* messages1_ExternalGilesSendersStartedMsg_Alloc();

/* Allocate a Array_t2_pony_CPPKey_val_USize_val without initialising it. */
Array_t2_pony_CPPKey_val_USize_val* Array_t2_pony_CPPKey_val_USize_val_Alloc();

/* Allocate a tcp_source_FramedSourceNotify_pony_CPPData_val without initialising it. */
tcp_source_FramedSourceNotify_pony_CPPData_val* tcp_source_FramedSourceNotify_pony_CPPData_val_Alloc();

/* Allocate a collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_ref* collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a initialization_WorkerInitializer without initialising it. */
initialization_WorkerInitializer* initialization_WorkerInitializer_Alloc();

/* Allocate a messages_ForwardMsg_pony_CPPData_val without initialising it. */
messages_ForwardMsg_pony_CPPData_val* messages_ForwardMsg_pony_CPPData_val_Alloc();

/* Allocate a u2_routing_BoundaryRoute_ref_routing_TypedRoute_topology_StateProcessor_pony_CPPState_ref_val_ref without initialising it. */
u2_routing_BoundaryRoute_ref_routing_TypedRoute_topology_StateProcessor_pony_CPPState_ref_val_ref* u2_routing_BoundaryRoute_ref_routing_TypedRoute_topology_StateProcessor_pony_CPPState_ref_val_ref_Alloc();

/* Allocate a topology_$36$98 without initialising it. */
topology_$36$98* topology_$36$98_Alloc();

/* Allocate a u2_topology_StateChange_pony_CPPState_ref_ref_None_val without initialising it. */
u2_topology_StateChange_pony_CPPState_ref_ref_None_val* u2_topology_StateChange_pony_CPPState_ref_ref_None_val_Alloc();

/* Allocate a collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_box without initialising it. */
collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_box* collections_MapPairs_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_box_Alloc();

/* Allocate a None without initialising it. */
None* None_Alloc();

/* Allocate a collections_HashMap_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections_HashEq_String_val_val* collections_HashMap_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_collections_HashEq_String_val_val_Alloc();

/* Allocate a network_$33$27 without initialising it. */
network_$33$27* network_$33$27_Alloc();

/* Allocate a u3_t2_U64_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U64_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U64_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a Array_u3_t2_U64_val_Bool_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U64_val_Bool_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U64_val_Bool_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a t2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_trn_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_trn without initialising it. */
t2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_trn_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_trn* t2_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_trn_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_trn_Alloc();

/* Allocate a u2_i2_recovery_Resilient_tag_routing_Producer_tag_None_val without initialising it. */
u2_i2_recovery_Resilient_tag_routing_Producer_tag_None_val* u2_i2_recovery_Resilient_tag_routing_Producer_tag_None_val_Alloc();

/* Allocate a topology_$36$126 without initialising it. */
topology_$36$126* topology_$36$126_Alloc();

/* Allocate a t2_u2_String_val_Array_U8_val_val_USize_val without initialising it. */
t2_u2_String_val_Array_U8_val_val_USize_val* t2_u2_String_val_Array_U8_val_val_USize_val_Alloc();

/* Allocate a AmbientAuth without initialising it. */
AmbientAuth* AmbientAuth_Alloc();

/* Allocate a topology_Partition_pony_CPPData_val_pony_CPPKey_val without initialising it. */
topology_Partition_pony_CPPData_val_pony_CPPKey_val* topology_Partition_pony_CPPData_val_pony_CPPKey_val_Alloc();

/* Allocate a t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val without initialising it. */
t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val* t2_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Alloc();

/* Allocate a ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_ref without initialising it. */
ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_ref* ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_ref_Alloc();

/* Allocate a routing_TypedRouteBuilder_pony_CPPData_val without initialising it. */
routing_TypedRouteBuilder_pony_CPPData_val* routing_TypedRouteBuilder_pony_CPPData_val_Alloc();

/* Allocate a boundary_$10$11 without initialising it. */
boundary_$10$11* boundary_$10$11_Alloc();

/* Allocate a u3_t2_U64_val_Bool_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U64_val_Bool_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U64_val_Bool_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a files_File without initialising it. */
files_File* files_File_Alloc();

/* Allocate a StdinNotify without initialising it. */
StdinNotify* StdinNotify_Alloc();

/* Allocate a t2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val without initialising it. */
t2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val* t2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val_Alloc();

/* Allocate a collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_val without initialising it. */
collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_val* collections_MapPairs_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionBuilder_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a ArrayValues_options__Option_ref_Array_options__Option_ref_ref without initialising it. */
ArrayValues_options__Option_ref_Array_options__Option_ref_ref* ArrayValues_options__Option_ref_Array_options__Option_ref_ref_Alloc();

/* Allocate a t2_U8_val_USize_val without initialising it. */
t2_U8_val_USize_val* t2_U8_val_USize_val_Alloc();

/* Allocate a Array_u3_t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_box without initialising it. */
collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_box* collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a u2_pony_CPPData_iso_None_val without initialising it. */
u2_pony_CPPData_iso_None_val* u2_pony_CPPData_iso_None_val_Alloc();

/* Allocate a collections_HashIs_topology_Step_tag without initialising it. */
collections_HashIs_topology_Step_tag* collections_HashIs_topology_Step_tag_Alloc();

/* Allocate a u2_U64_val_None_val without initialising it. */
u2_U64_val_None_val* u2_U64_val_None_val_Alloc();

/* Allocate a ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_ref without initialising it. */
ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_ref* ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_ref_Alloc();

/* Allocate a u2_topology_PartitionRouter_val_None_val without initialising it. */
u2_topology_PartitionRouter_val_None_val* u2_topology_PartitionRouter_val_None_val_Alloc();

/* Allocate a u4_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val_net_TCPListenAuth_val without initialising it. */
u4_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val_net_TCPListenAuth_val* u4_AmbientAuth_val_net_NetAuth_val_net_TCPAuth_val_net_TCPListenAuth_val_Alloc();

/* Allocate a ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_val without initialising it. */
ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_val* ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_val_Alloc();

/* Allocate a collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_ref without initialising it. */
collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_ref* collections_ListValues_time_Timer_ref_collections_ListNode_time_Timer_ref_ref_Alloc();

/* Allocate a files_FileRename without initialising it. */
files_FileRename* files_FileRename_Alloc();

/* Allocate a collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_box without initialising it. */
collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_box* collections_MapPairs_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_ref without initialising it. */
collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_ref* collections_MapValues_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_ref_Alloc();

/* Allocate a u2_String_val_Array_U8_val_val without initialising it. */
u2_String_val_Array_U8_val_val* u2_String_val_Array_U8_val_val_Alloc();

/* Allocate a boundary__UninitializedTimerInit without initialising it. */
boundary__UninitializedTimerInit* boundary__UninitializedTimerInit_Alloc();

/* Allocate a t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_val without initialising it. */
t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_val* t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_val_Alloc();

/* Allocate a boundary_DataReceiver without initialising it. */
boundary_DataReceiver* boundary_DataReceiver_Alloc();

/* Allocate a files_FileChown without initialising it. */
files_FileChown* files_FileChown_Alloc();

/* Allocate a initialization_$15$61 without initialising it. */
initialization_$15$61* initialization_$15$61_Alloc();

/* Allocate a collections_HashEq_boundary__BoundaryId_ref without initialising it. */
collections_HashEq_boundary__BoundaryId_ref* collections_HashEq_boundary__BoundaryId_ref_Alloc();

/* Allocate a messages_DeliveryMsg without initialising it. */
messages_DeliveryMsg* messages_DeliveryMsg_Alloc();

/* Allocate a collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val without initialising it. */
collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val* collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_Alloc();

/* Allocate a u2_routing_BoundaryRoute_ref_routing_TypedRoute_pony_CPPData_val_ref without initialising it. */
u2_routing_BoundaryRoute_ref_routing_TypedRoute_pony_CPPData_val_ref* u2_routing_BoundaryRoute_ref_routing_TypedRoute_pony_CPPData_val_ref_Alloc();

/* Allocate a messages_DataConnectMsg without initialising it. */
messages_DataConnectMsg* messages_DataConnectMsg_Alloc();

/* Allocate a ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_ref without initialising it. */
ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_ref* ArrayValues_data_channel_DataChannelListener_tag_Array_data_channel_DataChannelListener_tag_ref_Alloc();

/* Allocate a recovery_$37$30_String_val_U128_val without initialising it. */
recovery_$37$30_String_val_U128_val* recovery_$37$30_String_val_U128_val_Alloc();

/* Allocate a ArrayValues_String_val_Array_String_val_box without initialising it. */
ArrayValues_String_val_Array_String_val_box* ArrayValues_String_val_Array_String_val_box_Alloc();

/* Allocate a ArrayValues_U64_val_Array_U64_val_box without initialising it. */
ArrayValues_U64_val_Array_U64_val_box* ArrayValues_U64_val_Array_U64_val_box_Alloc();

/* Allocate a topology_$36$102_pony_CPPData_val without initialising it. */
topology_$36$102_pony_CPPData_val* topology_$36$102_pony_CPPData_val_Alloc();

/* Allocate a t2_String_val_topology_Router_val without initialising it. */
t2_String_val_topology_Router_val* t2_String_val_topology_Router_val_Alloc();

/* Allocate a t2_None_val_collections_ListNode_time_Timer_ref_ref without initialising it. */
t2_None_val_collections_ListNode_time_Timer_ref_ref* t2_None_val_collections_ListNode_time_Timer_ref_ref_Alloc();

/* Allocate a ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_box without initialising it. */
ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_box* ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_box_Alloc();

/* Allocate a collections_HashMap_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections_HashIs_data_channel_DataChannel_tag_val without initialising it. */
collections_HashMap_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections_HashIs_data_channel_DataChannel_tag_val* collections_HashMap_data_channel_DataChannel_tag_data_channel_DataChannel_tag_collections_HashIs_data_channel_DataChannel_tag_val_Alloc();

/* Allocate a messages_StartNormalDataSendingMsg without initialising it. */
messages_StartNormalDataSendingMsg* messages_StartNormalDataSendingMsg_Alloc();

/* Allocate a time_Timers without initialising it. */
time_Timers* time_Timers_Alloc();

/* Allocate a u2_t2_Array_U8_val_val_USize_val_None_val without initialising it. */
u2_t2_Array_U8_val_val_USize_val_None_val* u2_t2_Array_U8_val_val_USize_val_None_val_Alloc();

/* Allocate a routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_topology_StateProcessor_pony_CPPState_ref_val* routing_$35$74_topology_StateProcessor_pony_CPPState_ref_val_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a metrics_MetricsSinkNotify without initialising it. */
metrics_MetricsSinkNotify* metrics_MetricsSinkNotify_Alloc();

/* Allocate a ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_val without initialising it. */
ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_val* ArrayValues_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_val_Alloc();

/* Allocate a t2_ISize_val_ISize_val without initialising it. */
t2_ISize_val_ISize_val* t2_ISize_val_ISize_val_Alloc();

/* Allocate a collections_ListNode_http_Payload_val without initialising it. */
collections_ListNode_http_Payload_val* collections_ListNode_http_Payload_val_Alloc();

/* Allocate a collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_ref without initialising it. */
collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_ref* collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_ref_Alloc();

/* Allocate a ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_box without initialising it. */
ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_box* ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_box_Alloc();

/* Allocate a u2_files_FilePath_val_AmbientAuth_val without initialising it. */
u2_files_FilePath_val_AmbientAuth_val* u2_files_FilePath_val_AmbientAuth_val_Alloc();

/* Allocate a u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val without initialising it. */
u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val* u2_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_None_val_Alloc();

/* Allocate a collections_ListNode_t2_USize_val_U64_val without initialising it. */
collections_ListNode_t2_USize_val_U64_val* collections_ListNode_t2_USize_val_U64_val_Alloc();

/* Allocate a collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref without initialising it. */
collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref* collections_MapValues_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref_Alloc();

/* Allocate a t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag without initialising it. */
t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag* t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_Alloc();

/* Allocate a topology_$36$122_pony_CPPKey_val without initialising it. */
topology_$36$122_pony_CPPKey_val* topology_$36$122_pony_CPPKey_val_Alloc();

/* Allocate a u2_recovery_FileBackend_ref_recovery_DummyBackend_ref without initialising it. */
u2_recovery_FileBackend_ref_recovery_DummyBackend_ref* u2_recovery_FileBackend_ref_recovery_DummyBackend_ref_Alloc();

/* Allocate a collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_ref* collections_MapKeys_String_val_USize_val_collections_HashEq_String_val_val_collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a u3_t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_tcp_source_TCPSourceListener_tag_tcp_source_TCPSourceListener_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_PreStateRunner_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref without initialising it. */
topology_PreStateRunner_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref* topology_PreStateRunner_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_Alloc();

/* Allocate a t2_U64_val_t3_routing_Producer_tag_U64_val_U64_val without initialising it. */
t2_U64_val_t3_routing_Producer_tag_U64_val_U64_val* t2_U64_val_t3_routing_Producer_tag_U64_val_U64_val_Alloc();

/* Allocate a Array_u3_t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_String_box_Array_U8_val_box without initialising it. */
u2_String_box_Array_U8_val_box* u2_String_box_Array_U8_val_box_Alloc();

/* Allocate a collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val without initialising it. */
collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val* collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_Alloc();

/* Allocate a t2_U64_val_U128_val without initialising it. */
t2_U64_val_U128_val* t2_U64_val_U128_val_Alloc();

/* Allocate a messages_KeyedStepMigrationMsg_U8_val without initialising it. */
messages_KeyedStepMigrationMsg_U8_val* messages_KeyedStepMigrationMsg_U8_val_Alloc();

/* Allocate a Array_u3_t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a messages_IdentifyDataPortMsg without initialising it. */
messages_IdentifyDataPortMsg* messages_IdentifyDataPortMsg_Alloc();

/* Allocate a collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val without initialising it. */
collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val* collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_Alloc();

/* Allocate a collections_HashSet_data_channel_DataChannel_tag_collections_HashIs_data_channel_DataChannel_tag_val without initialising it. */
collections_HashSet_data_channel_DataChannel_tag_collections_HashIs_data_channel_DataChannel_tag_val* collections_HashSet_data_channel_DataChannel_tag_collections_HashIs_data_channel_DataChannel_tag_val_Alloc();

/* Allocate a messages1_ExternalDataMsg without initialising it. */
messages1_ExternalDataMsg* messages1_ExternalDataMsg_Alloc();

/* Allocate a t2_U64_val_routing__Route_box without initialising it. */
t2_U64_val_routing__Route_box* t2_U64_val_routing__Route_box_Alloc();

/* Allocate a collections_HashSet_String_val_collections_HashIs_String_val_val without initialising it. */
collections_HashSet_String_val_collections_HashIs_String_val_val* collections_HashSet_String_val_collections_HashIs_String_val_val_Alloc();

/* Allocate a ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_ref without initialising it. */
ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_ref* ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_ref_Alloc();

/* Allocate a t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_box without initialising it. */
t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_box* t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_box_Alloc();

/* Allocate a weighted_Weighted_pony_CPPKey_val without initialising it. */
weighted_Weighted_pony_CPPKey_val* weighted_Weighted_pony_CPPKey_val_Alloc();

/* Allocate a pony_CPPSourceDecoder without initialising it. */
pony_CPPSourceDecoder* pony_CPPSourceDecoder_Alloc();

/* Allocate a collections_HashMap_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections_HashEq_String_val_val* collections_HashMap_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_ref_collections_HashEq_String_val_val_Alloc();

/* Allocate a collections_HashEq_http__HostService_val without initialising it. */
collections_HashEq_http__HostService_val* collections_HashEq_http__HostService_val_Alloc();

/* Allocate a messages1__Shutdown without initialising it. */
messages1__Shutdown* messages1__Shutdown_Alloc();

/* Allocate a ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_box without initialising it. */
ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_box* ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_box_Alloc();

/* Allocate a Array_t2_U8_val_USize_val without initialising it. */
Array_t2_U8_val_USize_val* Array_t2_U8_val_USize_val_Alloc();

/* Allocate a topology_$36$99_pony_CPPData_val without initialising it. */
topology_$36$99_pony_CPPData_val* topology_$36$99_pony_CPPData_val_Alloc();

/* Allocate a u3_t2_U64_val_routing__Route_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U64_val_routing__Route_ref_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U64_val_routing__Route_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a http_Payload without initialising it. */
http_Payload* http_Payload_Alloc();

/* Allocate a ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_val without initialising it. */
ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_val* ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_val_Alloc();

/* Allocate a http_URL without initialising it. */
http_URL* http_URL_Alloc();

/* Allocate a messages1_ExternalStartMsg without initialising it. */
messages1_ExternalStartMsg* messages1_ExternalStartMsg_Alloc();

/* Allocate a boundary__DataReceiverAcceptingReplaysPhase without initialising it. */
boundary__DataReceiverAcceptingReplaysPhase* boundary__DataReceiverAcceptingReplaysPhase_Alloc();

/* Allocate a u6_http_URLPartUser_val_http_URLPartPassword_val_http_URLPartHost_val_http_URLPartPath_val_http_URLPartQuery_val_http_URLPartFragment_val without initialising it. */
u6_http_URLPartUser_val_http_URLPartPassword_val_http_URLPartHost_val_http_URLPartPath_val_http_URLPartQuery_val_http_URLPartFragment_val* u6_http_URLPartUser_val_http_URLPartPassword_val_http_URLPartHost_val_http_URLPartPath_val_http_URLPartQuery_val_http_URLPartFragment_val_Alloc();

/* Allocate a ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_val without initialising it. */
ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_val* ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_val_Alloc();

/* Allocate a collections_HashMap_U64_val_routing__Route_ref_collections_HashEq_U64_val_val without initialising it. */
collections_HashMap_U64_val_routing__Route_ref_collections_HashEq_U64_val_val* collections_HashMap_U64_val_routing__Route_ref_collections_HashEq_U64_val_val_Alloc();

/* Allocate a ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_ref without initialising it. */
ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_ref* ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_ref_Alloc();

/* Allocate a topology_PreStateData without initialising it. */
topology_PreStateData* topology_PreStateData_Alloc();

/* Allocate a ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_val without initialising it. */
ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_val* ArrayValues_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Array_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_val_Alloc();

/* Allocate a u2_routing_RouteLogic_ref_None_val without initialising it. */
u2_routing_RouteLogic_ref_None_val* u2_routing_RouteLogic_ref_None_val_Alloc();

/* Allocate a u2_topology_ProxyRouter_val_topology_DirectRouter_val without initialising it. */
u2_topology_ProxyRouter_val_topology_DirectRouter_val* u2_topology_ProxyRouter_val_topology_DirectRouter_val_Alloc();

/* Allocate a u3_t2_U128_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U128_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U128_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_ref without initialising it. */
ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_ref* ArrayValues_Array_u2_String_val_Array_U8_val_val_val_Array_Array_u2_String_val_Array_U8_val_val_val_ref_Alloc();

/* Allocate a collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val* collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a tcp_source_TCPSource without initialising it. */
tcp_source_TCPSource* tcp_source_TCPSource_Alloc();

/* Allocate a topology_$36$124_U64_val without initialising it. */
topology_$36$124_U64_val* topology_$36$124_U64_val_Alloc();

/* Allocate a $0$1_U32_val without initialising it. */
$0$1_U32_val* $0$1_U32_val_Alloc();

/* Allocate a collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_val without initialising it. */
collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_val* collections_MapValues_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_String_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag without initialising it. */
t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag* t2_boundary__BoundaryId_ref_boundary_DataReceiver_tag_Alloc();

/* Allocate a boundary_$10$17_pony_CPPData_val without initialising it. */
boundary_$10$17_pony_CPPData_val* boundary_$10$17_pony_CPPData_val_Alloc();

/* Allocate a topology_$36$133 without initialising it. */
topology_$36$133* topology_$36$133_Alloc();

/* Allocate a collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_ref without initialising it. */
collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_ref* collections_MapPairs_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_topology_Step_tag_collections_HashEq_U128_val_val_ref_Alloc();

/* Allocate a recovery_$37$23 without initialising it. */
recovery_$37$23* recovery_$37$23_Alloc();

/* Allocate a files_FileTruncate without initialising it. */
files_FileTruncate* files_FileTruncate_Alloc();

/* Allocate a topology_PauseBeforeMigrationNotify without initialising it. */
topology_PauseBeforeMigrationNotify* topology_PauseBeforeMigrationNotify_Alloc();

/* Allocate a collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_ref* collections_MapPairs_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_collections_HashMap_String_val_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a network_Cluster without initialising it. */
network_Cluster* network_Cluster_Alloc();

/* Allocate a Greater without initialising it. */
Greater* Greater_Alloc();

/* Allocate a collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val without initialising it. */
collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val* collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_Alloc();

/* Allocate a metrics_StartToEndCategory without initialising it. */
metrics_StartToEndCategory* metrics_StartToEndCategory_Alloc();

/* Allocate a collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_box without initialising it. */
collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_box* collections_SetValues_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_collections_HashSet_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_box_Alloc();

/* Allocate a tcp_source_SourceListenerNotify without initialising it. */
tcp_source_SourceListenerNotify* tcp_source_SourceListenerNotify_Alloc();

/* Allocate a recovery_$37$25 without initialising it. */
recovery_$37$25* recovery_$37$25_Alloc();

/* Allocate a collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref* collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a SourceLoc without initialising it. */
SourceLoc* SourceLoc_Alloc();

/* Allocate a u2_tcp_source_TCPSource_tag_None_val without initialising it. */
u2_tcp_source_TCPSource_tag_None_val* u2_tcp_source_TCPSource_tag_None_val_Alloc();

/* Allocate a collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val without initialising it. */
collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val* collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_Alloc();

/* Allocate a collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val* collections_HashMap_String_val_USize_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a u2_tcp_sink_TCPSink_tag_tcp_sink_EmptySink_tag without initialising it. */
u2_tcp_sink_TCPSink_tag_tcp_sink_EmptySink_tag* u2_tcp_sink_TCPSink_tag_tcp_sink_EmptySink_tag_Alloc();

/* Allocate a recovery__Replay without initialising it. */
recovery__Replay* recovery__Replay_Alloc();

/* Allocate a tcp_source_FramedSourceHandler_pony_CPPData_val without initialising it. */
tcp_source_FramedSourceHandler_pony_CPPData_val* tcp_source_FramedSourceHandler_pony_CPPData_val_Alloc();

/* Allocate a topology_EmptyOmniRouter without initialising it. */
topology_EmptyOmniRouter* topology_EmptyOmniRouter_Alloc();

/* Allocate a t2_pony_CPPKey_val_USize_val without initialising it. */
t2_pony_CPPKey_val_USize_val* t2_pony_CPPKey_val_USize_val_Alloc();

/* Allocate a topology_ProxyRouter without initialising it. */
topology_ProxyRouter* topology_ProxyRouter_Alloc();

/* Allocate a u2_t2_U128_val_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_None_val without initialising it. */
u2_t2_U128_val_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_None_val* u2_t2_U128_val_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_None_val_Alloc();

/* Allocate a topology_StateChangeBuilder_pony_CPPState_ref without initialising it. */
topology_StateChangeBuilder_pony_CPPState_ref* topology_StateChangeBuilder_pony_CPPState_ref_Alloc();

/* Allocate a recovery__RecoveryReplayer without initialising it. */
recovery__RecoveryReplayer* recovery__RecoveryReplayer_Alloc();

/* Allocate a collection_helpers_$39$0_String_val without initialising it. */
collection_helpers_$39$0_String_val* collection_helpers_$39$0_String_val_Alloc();

/* Allocate a u2_USize_val_None_val without initialising it. */
u2_USize_val_None_val* u2_USize_val_None_val_Alloc();

/* Allocate a collections_HashMap_U128_val_U128_val_collections_HashIs_U128_val_val without initialising it. */
collections_HashMap_U128_val_U128_val_collections_HashIs_U128_val_val* collections_HashMap_U128_val_U128_val_collections_HashIs_U128_val_val_Alloc();

/* Allocate a collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val* collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_Alloc();

/* Allocate a Array_Array_pony_CPPKey_val_ref without initialising it. */
Array_Array_pony_CPPKey_val_ref* Array_Array_pony_CPPKey_val_ref_Alloc();

/* Allocate a u2_options__Option_ref_None_val without initialising it. */
u2_options__Option_ref_None_val* u2_options__Option_ref_None_val_Alloc();

/* Allocate a u2_Array_t2_U64_val_USize_val_val_Array_U64_val_val without initialising it. */
u2_Array_t2_U64_val_USize_val_val_Array_U64_val_val* u2_Array_t2_U64_val_USize_val_val_Array_U64_val_val_Alloc();

/* Allocate a Array_t2_U64_val_t3_routing_Producer_tag_U64_val_U64_val without initialising it. */
Array_t2_U64_val_t3_routing_Producer_tag_U64_val_U64_val* Array_t2_U64_val_t3_routing_Producer_tag_U64_val_U64_val_Alloc();

/* Allocate a network_ControlSenderConnectNotifier without initialising it. */
network_ControlSenderConnectNotifier* network_ControlSenderConnectNotifier_Alloc();

/* Allocate a messages_ConnectionsReadyMsg without initialising it. */
messages_ConnectionsReadyMsg* messages_ConnectionsReadyMsg_Alloc();

/* Allocate a Array_topology_RunnerBuilder_val without initialising it. */
Array_topology_RunnerBuilder_val* Array_topology_RunnerBuilder_val_Alloc();

/* Allocate a collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val without initialising it. */
collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val* collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_box without initialising it. */
collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_box* collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_box_Alloc();

/* Allocate a recovery_$37$21 without initialising it. */
recovery_$37$21* recovery_$37$21_Alloc();

/* Allocate a initialization_ApplicationInitializer without initialising it. */
initialization_ApplicationInitializer* initialization_ApplicationInitializer_Alloc();

/* Allocate a recovery_$37$9 without initialising it. */
recovery_$37$9* recovery_$37$9_Alloc();

/* Allocate a u3_t2_U128_val_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U128_val_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U128_val_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_$36$85_pony_CPPState_ref without initialising it. */
topology_$36$85_pony_CPPState_ref* topology_$36$85_pony_CPPState_ref_Alloc();

/* Allocate a Array_u3_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_$36$112_pony_CPPData_val_pony_CPPKey_val without initialising it. */
topology_$36$112_pony_CPPData_val_pony_CPPKey_val* topology_$36$112_pony_CPPData_val_pony_CPPKey_val_Alloc();

/* Allocate a topology_$36$124_pony_CPPKey_val without initialising it. */
topology_$36$124_pony_CPPKey_val* topology_$36$124_pony_CPPKey_val_Alloc();

/* Allocate a Array_u3_t2_time_Timer_tag_time_Timer_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_time_Timer_tag_time_Timer_ref_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_time_Timer_tag_time_Timer_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_HashMap_U8_val_topology_ProxyAddress_val_collections_HashEq_U8_val_val without initialising it. */
collections_HashMap_U8_val_topology_ProxyAddress_val_collections_HashEq_U8_val_val* collections_HashMap_U8_val_topology_ProxyAddress_val_collections_HashEq_U8_val_val_Alloc();

/* Allocate a u2_recovery_EventLog_tag_None_val without initialising it. */
u2_recovery_EventLog_tag_None_val* u2_recovery_EventLog_tag_None_val_Alloc();

/* Allocate a collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val without initialising it. */
collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val* collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_Alloc();

/* Allocate a weighted_Weighted_U64_val without initialising it. */
weighted_Weighted_U64_val* weighted_Weighted_U64_val_Alloc();

/* Allocate a collections_List_http_Payload_val without initialising it. */
collections_List_http_Payload_val* collections_List_http_Payload_val_Alloc();

/* Allocate a collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_val without initialising it. */
collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_val* collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_val_Alloc();

/* Allocate a u3_t2_String_val_metrics__MetricsReporter_box_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_metrics__MetricsReporter_box_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_metrics__MetricsReporter_box_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a Array_u3_t2_U128_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U128_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U128_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_HashMap_pony_CPPKey_val_topology_ProxyAddress_val_collections_HashEq_pony_CPPKey_val_val without initialising it. */
collections_HashMap_pony_CPPKey_val_topology_ProxyAddress_val_collections_HashEq_pony_CPPKey_val_val* collections_HashMap_pony_CPPKey_val_topology_ProxyAddress_val_collections_HashEq_pony_CPPKey_val_val_Alloc();

/* Allocate a collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box without initialising it. */
collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box* collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a u3_t2_topology_Initializable_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_topology_Initializable_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_topology_Initializable_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_AmbientAuth_val_None_val without initialising it. */
u2_AmbientAuth_val_None_val* u2_AmbientAuth_val_None_val_Alloc();

/* Allocate a Main without initialising it. */
Main* Main_Alloc();

/* Allocate a collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val* collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_Alloc();

/* Allocate a ArrayValues_String_val_Array_String_val_tag without initialising it. */
ArrayValues_String_val_Array_String_val_tag* ArrayValues_String_val_Array_String_val_tag_Alloc();

/* Allocate a collections_HashIs_data_channel_DataChannel_tag without initialising it. */
collections_HashIs_data_channel_DataChannel_tag* collections_HashIs_data_channel_DataChannel_tag_Alloc();

/* Allocate a t2_I64_val_USize_val without initialising it. */
t2_I64_val_USize_val* t2_I64_val_USize_val_Alloc();

/* Allocate a Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val without initialising it. */
Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val* Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Alloc();

/* Allocate a collections_Sort_Array_U128_val_ref_U128_val without initialising it. */
collections_Sort_Array_U128_val_ref_U128_val* collections_Sort_Array_U128_val_ref_U128_val_Alloc();

/* Allocate a collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_box without initialising it. */
collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_box* collections_MapPairs_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_collections_HashMap_String_val_initialization_LocalTopology_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box without initialising it. */
collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box* collections_MapKeys_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a boundary_$10$19 without initialising it. */
boundary_$10$19* boundary_$10$19_Alloc();

/* Allocate a u2_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_None_val without initialising it. */
u2_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_None_val* u2_dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_trn_None_val_Alloc();

/* Allocate a ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_box without initialising it. */
ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_box* ArrayValues_topology_PreStateData_val_Array_topology_PreStateData_val_box_Alloc();

/* Allocate a collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_box without initialising it. */
collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_box* collections_SetValues_topology_Step_tag_collections_HashIs_topology_Step_tag_val_collections_HashSet_topology_Step_tag_collections_HashIs_topology_Step_tag_val_box_Alloc();

/* Allocate a u3_t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_collections_ListNode_t2_USize_val_U64_val_ref_None_val without initialising it. */
u2_collections_ListNode_t2_USize_val_U64_val_ref_None_val* u2_collections_ListNode_t2_USize_val_U64_val_ref_None_val_Alloc();

/* Allocate a Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val without initialising it. */
Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val* Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Alloc();

/* Allocate a t2_U64_val_routing__Route_val without initialising it. */
t2_U64_val_routing__Route_val* t2_U64_val_routing__Route_val_Alloc();

/* Allocate a collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val without initialising it. */
collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val* collections_HashMap_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U64_val_val_Alloc();

/* Allocate a topology_$36$113_pony_CPPData_val_U8_val without initialising it. */
topology_$36$113_pony_CPPData_val_U8_val* topology_$36$113_pony_CPPData_val_U8_val_Alloc();

/* Allocate a collections_HashIs_data_channel_DataChannelListener_tag without initialising it. */
collections_HashIs_data_channel_DataChannelListener_tag* collections_HashIs_data_channel_DataChannelListener_tag_Alloc();

/* Allocate a collections_HashMap_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections_HashEq_String_val_val* collections_HashMap_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a initialization_$15$68 without initialising it. */
initialization_$15$68* initialization_$15$68_Alloc();

/* Allocate a collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_ref without initialising it. */
collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_ref* collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_ref_Alloc();

/* Allocate a u2_net_TCPListener_tag_None_val without initialising it. */
u2_net_TCPListener_tag_None_val* u2_net_TCPListener_tag_None_val_Alloc();

/* Allocate a collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref without initialising it. */
collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref* collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref_Alloc();

/* Allocate a initialization_$15$75 without initialising it. */
initialization_$15$75* initialization_$15$75_Alloc();

/* Allocate a Array_u3_t2_U128_val_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U128_val_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U128_val_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a boundary_$10$24 without initialising it. */
boundary_$10$24* boundary_$10$24_Alloc();

/* Allocate a u3_t2_String_val_topology_PartitionRouter_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_topology_PartitionRouter_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_topology_PartitionRouter_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a recovery__WaitForReconnections without initialising it. */
recovery__WaitForReconnections* recovery__WaitForReconnections_Alloc();

/* Allocate a random_Random without initialising it. */
random_Random* random_Random_Alloc();

/* Allocate a topology_ComputationRunner_pony_CPPData_val_pony_CPPData_val without initialising it. */
topology_ComputationRunner_pony_CPPData_val_pony_CPPData_val* topology_ComputationRunner_pony_CPPData_val_pony_CPPData_val_Alloc();

/* Allocate a t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref without initialising it. */
t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref* t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Alloc();

/* Allocate a u2_collections_ListNode_time_Timer_ref_ref_None_val without initialising it. */
u2_collections_ListNode_time_Timer_ref_ref_None_val* u2_collections_ListNode_time_Timer_ref_ref_None_val_Alloc();

/* Allocate a u2_collections_List_t2_Array_U8_val_val_USize_val_ref_None_val without initialising it. */
u2_collections_List_t2_Array_U8_val_val_USize_val_ref_None_val* u2_collections_List_t2_Array_U8_val_val_USize_val_ref_None_val_Alloc();

/* Allocate a $0$13_routing_Producer_tag without initialising it. */
$0$13_routing_Producer_tag* $0$13_routing_Producer_tag_Alloc();

/* Allocate a Array_u3_t2_String_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_topology_Router_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a data_channel__DataReceiver without initialising it. */
data_channel__DataReceiver* data_channel__DataReceiver_Alloc();

/* Allocate a network_$33$24_pony_CPPKey_val without initialising it. */
network_$33$24_pony_CPPKey_val* network_$33$24_pony_CPPKey_val_Alloc();

/* Allocate a weighted_Weighted_U8_val without initialising it. */
weighted_Weighted_U8_val* weighted_Weighted_U8_val_Alloc();

/* Allocate a ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_box without initialising it. */
ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_box* ArrayValues_pony_CPPKey_val_Array_pony_CPPKey_val_box_Alloc();

/* Allocate a files_FileChmod without initialising it. */
files_FileChmod* files_FileChmod_Alloc();

/* Allocate a tcp_source_SourceBuilderBuilder without initialising it. */
tcp_source_SourceBuilderBuilder* tcp_source_SourceBuilderBuilder_Alloc();

/* Allocate a wallaroo_BasicPipeline without initialising it. */
wallaroo_BasicPipeline* wallaroo_BasicPipeline_Alloc();

/* Allocate a files_FileTime without initialising it. */
files_FileTime* files_FileTime_Alloc();

/* Allocate a metrics_ComputationCategory without initialising it. */
metrics_ComputationCategory* metrics_ComputationCategory_Alloc();

/* Allocate a collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_ref without initialising it. */
collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_ref* collections_MapValues_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val without initialising it. */
t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val* t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Alloc();

/* Allocate a collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_val without initialising it. */
collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_val* collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_val_Alloc();

/* Allocate a u2_None_val_wallaroo_PipelineBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_ref without initialising it. */
u2_None_val_wallaroo_PipelineBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_ref* u2_None_val_wallaroo_PipelineBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_ref_Alloc();

/* Allocate a collections_HashEq_U8_val without initialising it. */
collections_HashEq_U8_val* collections_HashEq_U8_val_Alloc();

/* Allocate a collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_box without initialising it. */
collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_box* collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_box_Alloc();

/* Allocate a collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_val without initialising it. */
collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_val* collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_val_Alloc();

/* Allocate a Array_u3_t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_val without initialising it. */
collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_val* collections_SetValues_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_collections_HashSet_tcp_source_TCPSourceListener_tag_collections_HashIs_tcp_source_TCPSourceListener_tag_val_val_Alloc();

/* Allocate a collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_val without initialising it. */
collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_val* collections_MapPairs_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_boundary_OutgoingBoundary_tag_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a serialise_InputSerialisedAuth without initialising it. */
serialise_InputSerialisedAuth* serialise_InputSerialisedAuth_Alloc();

/* Allocate a files_FileLink without initialising it. */
files_FileLink* files_FileLink_Alloc();

/* Allocate a u2_recovery_Recovery_tag_None_val without initialising it. */
u2_recovery_Recovery_tag_None_val* u2_recovery_Recovery_tag_None_val_Alloc();

/* Allocate a u2_collections_ListNode_time_Timer_ref_box_None_val without initialising it. */
u2_collections_ListNode_time_Timer_ref_box_None_val* u2_collections_ListNode_time_Timer_ref_box_None_val_Alloc();

/* Allocate a messages_StepMigrationCompleteMsg without initialising it. */
messages_StepMigrationCompleteMsg* messages_StepMigrationCompleteMsg_Alloc();

/* Allocate a network_ControlChannelListenNotifier without initialising it. */
network_ControlChannelListenNotifier* network_ControlChannelListenNotifier_Alloc();

/* Allocate a data_channel_DataChannelListenNotifier without initialising it. */
data_channel_DataChannelListenNotifier* data_channel_DataChannelListenNotifier_Alloc();

/* Allocate a collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_ref without initialising it. */
collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_ref* collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a boundary_$10$18_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
boundary_$10$18_topology_StateProcessor_pony_CPPState_ref_val* boundary_$10$18_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a topology_StateChange_pony_CPPState_ref without initialising it. */
topology_StateChange_pony_CPPState_ref* topology_StateChange_pony_CPPState_ref_Alloc();

/* Allocate a t2_u2_String_val_None_val_Bool_val without initialising it. */
t2_u2_String_val_None_val_Bool_val* t2_u2_String_val_None_val_Bool_val_Alloc();

/* Allocate a http_URLPartQuery without initialising it. */
http_URLPartQuery* http_URLPartQuery_Alloc();

/* Allocate a Array_u3_t2_U8_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U8_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U8_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u3_t2_U64_val_routing__Route_box_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U64_val_routing__Route_box_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U64_val_routing__Route_box_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a recovery__WaitingForBoundaryCounts without initialising it. */
recovery__WaitingForBoundaryCounts* recovery__WaitingForBoundaryCounts_Alloc();

/* Allocate a u3_t2_routing_RouteLogic_ref_routing_RouteLogic_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_routing_RouteLogic_ref_routing_RouteLogic_ref_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_routing_RouteLogic_ref_routing_RouteLogic_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_HashMap_U64_val_topology_ProxyAddress_val_collections_HashEq_U64_val_val without initialising it. */
collections_HashMap_U64_val_topology_ProxyAddress_val_collections_HashEq_U64_val_val* collections_HashMap_U64_val_topology_ProxyAddress_val_collections_HashEq_U64_val_val_Alloc();

/* Allocate a u2_t2_USize_val_U64_val_None_val without initialising it. */
u2_t2_USize_val_U64_val_None_val* u2_t2_USize_val_U64_val_None_val_Alloc();

/* Allocate a data_channel_$45$8 without initialising it. */
data_channel_$45$8* data_channel_$45$8_Alloc();

/* Allocate a u3_String_val_Array_String_val_val_None_val without initialising it. */
u3_String_val_Array_String_val_val_None_val* u3_String_val_Array_String_val_val_None_val_Alloc();

/* Allocate a files_FileRemove without initialising it. */
files_FileRemove* files_FileRemove_Alloc();

/* Allocate a topology_DefaultStateable without initialising it. */
topology_DefaultStateable* topology_DefaultStateable_Alloc();

/* Allocate a topology_PartitionRouter without initialising it. */
topology_PartitionRouter* topology_PartitionRouter_Alloc();

/* Allocate a files_FileLookup without initialising it. */
files_FileLookup* files_FileLookup_Alloc();

/* Allocate a t2_U8_val_U128_val without initialising it. */
t2_U8_val_U128_val* t2_U8_val_U128_val_Alloc();

/* Allocate a ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_ref without initialising it. */
ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_ref* ArrayValues_tcp_source_TCPSourceListenerBuilder_val_Array_tcp_source_TCPSourceListenerBuilder_val_ref_Alloc();

/* Allocate a u3_Array_String_val_val_String_val_None_val without initialising it. */
u3_Array_String_val_val_String_val_None_val* u3_Array_String_val_val_String_val_None_val_Alloc();

/* Allocate a u2_time_Timer_ref_None_val without initialising it. */
u2_time_Timer_ref_None_val* u2_time_Timer_ref_None_val_Alloc();

/* Allocate a u2_data_channel_DataChannel_tag_None_val without initialising it. */
u2_data_channel_DataChannel_tag_None_val* u2_data_channel_DataChannel_tag_None_val_Alloc();

/* Allocate a topology_$36$86_pony_CPPState_ref without initialising it. */
topology_$36$86_pony_CPPState_ref* topology_$36$86_pony_CPPState_ref_Alloc();

/* Allocate a recovery_$37$27 without initialising it. */
recovery_$37$27* recovery_$37$27_Alloc();

/* Allocate a files_FileOK without initialising it. */
files_FileOK* files_FileOK_Alloc();

/* Allocate a AsioEventNotify without initialising it. */
AsioEventNotify* AsioEventNotify_Alloc();

/* Allocate a u3_t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U64_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_None_val_String_val without initialising it. */
u2_None_val_String_val* u2_None_val_String_val_Alloc();

/* Allocate a collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_ref without initialising it. */
collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_ref* collections_MapValues_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_collections_HashMap_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_U8_val_val_ref_Alloc();

/* Allocate a Array_u3_t2_routing_RouteLogic_ref_routing_RouteLogic_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_routing_RouteLogic_ref_routing_RouteLogic_ref_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_routing_RouteLogic_ref_routing_RouteLogic_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_$36$106 without initialising it. */
topology_$36$106* topology_$36$106_Alloc();

/* Allocate a u3_t2_routing_Consumer_tag_routing_Route_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_routing_Consumer_tag_routing_Route_ref_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_routing_Consumer_tag_routing_Route_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_tcp_source_TCPSourceListener_tag_None_val without initialising it. */
u2_tcp_source_TCPSourceListener_tag_None_val* u2_tcp_source_TCPSourceListener_tag_None_val_Alloc();

/* Allocate a collections_HashEq_U64_val without initialising it. */
collections_HashEq_U64_val* collections_HashEq_U64_val_Alloc();

/* Allocate a pony_CPPComputation without initialising it. */
pony_CPPComputation* pony_CPPComputation_Alloc();

/* Allocate a messages1__StartGilesSenders without initialising it. */
messages1__StartGilesSenders* messages1__StartGilesSenders_Alloc();

/* Allocate a collections_HashEq_U128_val without initialising it. */
collections_HashEq_U128_val* collections_HashEq_U128_val_Alloc();

/* Allocate a u2_initialization_ApplicationInitializer_tag_None_val without initialising it. */
u2_initialization_ApplicationInitializer_tag_None_val* u2_initialization_ApplicationInitializer_tag_None_val_Alloc();

/* Allocate a dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val without initialising it. */
dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val* dag_Dag_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_Alloc();

/* Allocate a routing_Routes without initialising it. */
routing_Routes* routing_Routes_Alloc();

/* Allocate a t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box without initialising it. */
t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box* t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a Array_u3_t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_$36$116 without initialising it. */
topology_$36$116* topology_$36$116_Alloc();

/* Allocate a t2_None_val_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref without initialising it. */
t2_None_val_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref* t2_None_val_collections_ListNode_t2_u2_String_val_Array_U8_val_val_USize_val_ref_Alloc();

/* Allocate a t2_routing_RouteLogic_ref_routing_RouteLogic_ref without initialising it. */
t2_routing_RouteLogic_ref_routing_RouteLogic_ref* t2_routing_RouteLogic_ref_routing_RouteLogic_ref_Alloc();

/* Allocate a collections_List_t2_USize_val_U64_val without initialising it. */
collections_List_t2_USize_val_U64_val* collections_List_t2_USize_val_U64_val_Alloc();

/* Allocate a u2_initialization_WorkerInitializer_tag_None_val without initialising it. */
u2_initialization_WorkerInitializer_tag_None_val* u2_initialization_WorkerInitializer_tag_None_val_Alloc();

/* Allocate a t2_u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val_u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val without initialising it. */
t2_u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val_u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val* t2_u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val_u2_collections_ListNode_t2_Array_U8_val_val_USize_val_ref_None_val_Alloc();

/* Allocate a messages_MigrationBatchCompleteMsg without initialising it. */
messages_MigrationBatchCompleteMsg* messages_MigrationBatchCompleteMsg_Alloc();

/* Allocate a net_TCPConnection without initialising it. */
net_TCPConnection* net_TCPConnection_Alloc();

/* Allocate a topology_LocalPartitionRouter_pony_CPPData_val_U8_val without initialising it. */
topology_LocalPartitionRouter_pony_CPPData_val_U8_val* topology_LocalPartitionRouter_pony_CPPData_val_U8_val_Alloc();

/* Allocate a u3_t2_routing_Consumer_tag_routing_Route_box_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_routing_Consumer_tag_routing_Route_box_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_routing_Consumer_tag_routing_Route_box_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_$36$112_pony_CPPData_val_U64_val without initialising it. */
topology_$36$112_pony_CPPData_val_U64_val* topology_$36$112_pony_CPPData_val_U64_val_Alloc();

/* Allocate a u2_topology_ProxyAddress_val_None_val without initialising it. */
u2_topology_ProxyAddress_val_None_val* u2_topology_ProxyAddress_val_None_val_Alloc();

/* Allocate a topology_LocalPartitionRouter_pony_CPPData_val_U64_val without initialising it. */
topology_LocalPartitionRouter_pony_CPPData_val_U64_val* topology_LocalPartitionRouter_pony_CPPData_val_U64_val_Alloc();

/* Allocate a t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_val_U64_val_U64_val_String_val_String_val without initialising it. */
t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_val_U64_val_U64_val_String_val_String_val* t10_String_val_String_val_String_val_String_val_U16_val_metrics_Histogram_val_U64_val_U64_val_String_val_String_val_Alloc();

/* Allocate a u3_t2_boundary__BoundaryId_box_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_boundary__BoundaryId_box_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_boundary__BoundaryId_box_boundary_DataReceiver_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a metrics_DefaultMetricsMonitor without initialising it. */
metrics_DefaultMetricsMonitor* metrics_DefaultMetricsMonitor_Alloc();

/* Allocate a t2_U128_val_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val without initialising it. */
t2_U128_val_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val* t2_U128_val_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_Alloc();

/* Allocate a topology_KeyedStateSubpartition_pony_CPPData_val_U8_val without initialising it. */
topology_KeyedStateSubpartition_pony_CPPData_val_U8_val* topology_KeyedStateSubpartition_pony_CPPData_val_U8_val_Alloc();

/* Allocate a net_TCPConnectionNotify without initialising it. */
net_TCPConnectionNotify* net_TCPConnectionNotify_Alloc();

/* Allocate a u3_t2_String_val_metrics__MetricsReporter_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_metrics__MetricsReporter_ref_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_metrics__MetricsReporter_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a recovery_CheckCounts_String_val_U128_val without initialising it. */
recovery_CheckCounts_String_val_U128_val* recovery_CheckCounts_String_val_U128_val_Alloc();

/* Allocate a topology_StateProcessor_pony_CPPState_ref without initialising it. */
topology_StateProcessor_pony_CPPState_ref* topology_StateProcessor_pony_CPPState_ref_Alloc();

/* Allocate a routing_RouteBuilder without initialising it. */
routing_RouteBuilder* routing_RouteBuilder_Alloc();

/* Allocate a tcp_sink_TCPSinkBuilder without initialising it. */
tcp_sink_TCPSinkBuilder* tcp_sink_TCPSinkBuilder_Alloc();

/* Allocate a t2_net_TCPListener_tag_net_TCPListener_tag without initialising it. */
t2_net_TCPListener_tag_net_TCPListener_tag* t2_net_TCPListener_tag_net_TCPListener_tag_Alloc();

/* Allocate a messages_ReplayCompleteMsg without initialising it. */
messages_ReplayCompleteMsg* messages_ReplayCompleteMsg_Alloc();

/* Allocate a messages1__Data without initialising it. */
messages1__Data* messages1__Data_Alloc();

/* Allocate a u3_t2_String_val_topology_StateSubpartition_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_topology_StateSubpartition_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_topology_StateSubpartition_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a t5_topology_Step_ref_U128_val_None_val_U64_val_U64_val without initialising it. */
t5_topology_Step_ref_U128_val_None_val_U64_val_U64_val* t5_topology_Step_ref_U128_val_None_val_U64_val_U64_val_Alloc();

/* Allocate a collections_HashMap_http__HostService_val_http__ClientConnection_tag_collections_HashEq_http__HostService_val_val without initialising it. */
collections_HashMap_http__HostService_val_http__ClientConnection_tag_collections_HashEq_http__HostService_val_val* collections_HashMap_http__HostService_val_http__ClientConnection_tag_collections_HashEq_http__HostService_val_val_Alloc();

/* Allocate a network_$33$37 without initialising it. */
network_$33$37* network_$33$37_Alloc();

/* Allocate a t3_U8_val_U128_val_topology_Step_tag without initialising it. */
t3_U8_val_U128_val_topology_Step_tag* t3_U8_val_U128_val_topology_Step_tag_Alloc();

/* Allocate a collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_ref without initialising it. */
collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_ref* collections_MapValues_U128_val_U64_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_ref_Alloc();

/* Allocate a http_URLEncode without initialising it. */
http_URLEncode* http_URLEncode_Alloc();

/* Allocate a collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_ref without initialising it. */
collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_ref* collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_ref_Alloc();

/* Allocate a Iterator_u2_String_box_Array_U8_val_box without initialising it. */
Iterator_u2_String_box_Array_U8_val_box* Iterator_u2_String_box_Array_U8_val_box_Alloc();

/* Allocate a t2_U64_val_USize_val without initialising it. */
t2_U64_val_USize_val* t2_U64_val_USize_val_Alloc();

/* Allocate a options__ErrorPrinter without initialising it. */
options__ErrorPrinter* options__ErrorPrinter_Alloc();

/* Allocate a collections_HashIs_tcp_source_TCPSource_tag without initialising it. */
collections_HashIs_tcp_source_TCPSource_tag* collections_HashIs_tcp_source_TCPSource_tag_Alloc();

/* Allocate a time_TimerNotify without initialising it. */
time_TimerNotify* time_TimerNotify_Alloc();

/* Allocate a t2_U128_val_String_val without initialising it. */
t2_U128_val_String_val* t2_U128_val_String_val_Alloc();

/* Allocate a tcp_source_$40$9_pony_CPPData_val without initialising it. */
tcp_source_$40$9_pony_CPPData_val* tcp_source_$40$9_pony_CPPData_val_Alloc();

/* Allocate a ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_val without initialising it. */
ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_val* ArrayValues_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_Array_t5_routing_Producer_tag_U128_val_u2_Array_U64_val_val_None_val_U64_val_U64_val_val_Alloc();

/* Allocate a messages_RequestBoundaryCountMsg without initialising it. */
messages_RequestBoundaryCountMsg* messages_RequestBoundaryCountMsg_Alloc();

/* Allocate a routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_topology_StateProcessor_pony_CPPState_ref_val* routing_$35$75_topology_StateProcessor_pony_CPPState_ref_val_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a http_URLPartUser without initialising it. */
http_URLPartUser* http_URLPartUser_Alloc();

/* Allocate a topology_AugmentablePartitionRouter_pony_CPPKey_val without initialising it. */
topology_AugmentablePartitionRouter_pony_CPPKey_val* topology_AugmentablePartitionRouter_pony_CPPKey_val_Alloc();

/* Allocate a time_Timer without initialising it. */
time_Timer* time_Timer_Alloc();

/* Allocate a boundary__DataReceiverProcessingPhase without initialising it. */
boundary__DataReceiverProcessingPhase* boundary__DataReceiverProcessingPhase_Alloc();

/* Allocate a net_TCPConnectAuth without initialising it. */
net_TCPConnectAuth* net_TCPConnectAuth_Alloc();

/* Allocate a collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val without initialising it. */
collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val* collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_val_Alloc();

/* Allocate a Array_u3_t2_String_val_topology_PartitionBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_topology_PartitionBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_topology_PartitionBuilder_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a initialization_$15$66 without initialising it. */
initialization_$15$66* initialization_$15$66_Alloc();

/* Allocate a collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_val without initialising it. */
collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_val* collections_MapValues_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_collections_HashMap_String_val_metrics__MetricsReporter_ref_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a initialization_$15$74 without initialising it. */
initialization_$15$74* initialization_$15$74_Alloc();

/* Allocate a Array_t2_U64_val_USize_val without initialising it. */
Array_t2_U64_val_USize_val* Array_t2_U64_val_USize_val_Alloc();

/* Allocate a u2_topology_ProxyAddress_val_U128_val without initialising it. */
u2_topology_ProxyAddress_val_U128_val* u2_topology_ProxyAddress_val_U128_val_Alloc();

/* Allocate a Array_u3_t2_U128_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U128_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U128_val_String_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a t3_routing_Producer_tag_U64_val_U64_val without initialising it. */
t3_routing_Producer_tag_U64_val_U64_val* t3_routing_Producer_tag_U64_val_U64_val_Alloc();

/* Allocate a collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_val without initialising it. */
collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_val* collections_MapKeys_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a t2_time_Timer_tag_time_Timer_val without initialising it. */
t2_time_Timer_tag_time_Timer_val* t2_time_Timer_tag_time_Timer_val_Alloc();

/* Allocate a Array_u3_t2_U128_val_u2_topology_ProxyAddress_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U128_val_u2_topology_ProxyAddress_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U128_val_u2_topology_ProxyAddress_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box without initialising it. */
t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box* t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a topology_$36$123_U8_val without initialising it. */
topology_$36$123_U8_val* topology_$36$123_U8_val_Alloc();

/* Allocate a ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_box without initialising it. */
ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_box* ArrayValues_topology_RunnerBuilder_val_Array_topology_RunnerBuilder_val_box_Alloc();

/* Allocate a messages_DataMsg without initialising it. */
messages_DataMsg* messages_DataMsg_Alloc();

/* Allocate a t2_u2_collections_ListNode_time_Timer_ref_ref_None_val_u2_collections_ListNode_time_Timer_ref_ref_None_val without initialising it. */
t2_u2_collections_ListNode_time_Timer_ref_ref_None_val_u2_collections_ListNode_time_Timer_ref_ref_None_val* t2_u2_collections_ListNode_time_Timer_ref_ref_None_val_u2_collections_ListNode_time_Timer_ref_ref_None_val_Alloc();

/* Allocate a options_Optional without initialising it. */
options_Optional* options_Optional_Alloc();

/* Allocate a routing_$35$74_pony_CPPData_val_pony_CPPData_val without initialising it. */
routing_$35$74_pony_CPPData_val_pony_CPPData_val* routing_$35$74_pony_CPPData_val_pony_CPPData_val_Alloc();

/* Allocate a collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_box without initialising it. */
collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_box* collections_SetValues_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_collections_HashSet_topology_Initializable_tag_collections_HashIs_topology_Initializable_tag_val_box_Alloc();

/* Allocate a messages_InformJoiningWorkerMsg without initialising it. */
messages_InformJoiningWorkerMsg* messages_InformJoiningWorkerMsg_Alloc();

/* Allocate a topology_$36$131 without initialising it. */
topology_$36$131* topology_$36$131_Alloc();

/* Allocate a boundary_$10$13 without initialising it. */
boundary_$10$13* boundary_$10$13_Alloc();

/* Allocate a topology_PartitionFunction_pony_CPPData_val_U8_val without initialising it. */
topology_PartitionFunction_pony_CPPData_val_U8_val* topology_PartitionFunction_pony_CPPData_val_U8_val_Alloc();

/* Allocate a network_$33$40 without initialising it. */
network_$33$40* network_$33$40_Alloc();

/* Allocate a u2_metrics__MetricsReporter_ref_None_val without initialising it. */
u2_metrics__MetricsReporter_ref_None_val* u2_metrics__MetricsReporter_ref_None_val_Alloc();

/* Allocate a routing__RouteLogic without initialising it. */
routing__RouteLogic* routing__RouteLogic_Alloc();

/* Allocate a collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_ref without initialising it. */
collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_ref* collections_MapValues_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_collections_HashMap_boundary__BoundaryId_ref_boundary_DataReceiver_tag_collections_HashEq_boundary__BoundaryId_ref_val_ref_Alloc();

/* Allocate a wallaroo_Application without initialising it. */
wallaroo_Application* wallaroo_Application_Alloc();

/* Allocate a serialise_OutputSerialisedAuth without initialising it. */
serialise_OutputSerialisedAuth* serialise_OutputSerialisedAuth_Alloc();

/* Allocate a collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box without initialising it. */
collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box* collections_MapPairs_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_box_Alloc();

/* Allocate a pony_CPPPartitionFunction without initialising it. */
pony_CPPPartitionFunction* pony_CPPPartitionFunction_Alloc();

/* Allocate a pony_CPPStateBuilder without initialising it. */
pony_CPPStateBuilder* pony_CPPStateBuilder_Alloc();

/* Allocate a topology_$36$125_U8_val without initialising it. */
topology_$36$125_U8_val* topology_$36$125_U8_val_Alloc();

/* Allocate a u3_t2_String_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_ref without initialising it. */
collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_ref* collections_MapValues_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_ref_Alloc();

/* Allocate a collections_HashMap_U128_val_topology_Router_val_collections_HashEq_U128_val_val without initialising it. */
collections_HashMap_U128_val_topology_Router_val_collections_HashEq_U128_val_val* collections_HashMap_U128_val_topology_Router_val_collections_HashEq_U128_val_val_Alloc();

/* Allocate a ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_ref without initialising it. */
ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_ref* ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_ref_Alloc();

/* Allocate a routing_$35$75_pony_CPPData_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val without initialising it. */
routing_$35$75_pony_CPPData_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val* routing_$35$75_pony_CPPData_val_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val_Alloc();

/* Allocate a topology_RunnerSequenceBuilder without initialising it. */
topology_RunnerSequenceBuilder* topology_RunnerSequenceBuilder_Alloc();

/* Allocate a collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val* collections_HashMap_String_val_topology_PartitionRouter_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a u3_t2_pony_CPPKey_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_pony_CPPKey_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_pony_CPPKey_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a network_$33$21 without initialising it. */
network_$33$21* network_$33$21_Alloc();

/* Allocate a Array_u3_t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a t2_String_val_String_val without initialising it. */
t2_String_val_String_val* t2_String_val_String_val_Alloc();

/* Allocate a boundary_$10$14 without initialising it. */
boundary_$10$14* boundary_$10$14_Alloc();

/* Allocate a collections_HashIs_Any_tag without initialising it. */
collections_HashIs_Any_tag* collections_HashIs_Any_tag_Alloc();

/* Allocate a ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_box without initialising it. */
ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_box* ArrayValues_u2_String_val_Array_U8_val_val_Array_u2_String_val_Array_U8_val_val_box_Alloc();

/* Allocate a ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_val without initialising it. */
ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_val* ArrayValues_t3_U64_val_U128_val_topology_Step_tag_Array_t3_U64_val_U128_val_topology_Step_tag_val_Alloc();

/* Allocate a messages1__Ready without initialising it. */
messages1__Ready* messages1__Ready_Alloc();

/* Allocate a t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val without initialising it. */
t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val* t2_String_val_u2_Array_topology_StepBuilder_val_val_topology_ProxyAddress_val_Alloc();

/* Allocate a ArrayValues_U8_val_Array_U8_val_box without initialising it. */
ArrayValues_U8_val_Array_U8_val_box* ArrayValues_U8_val_Array_U8_val_box_Alloc();

/* Allocate a t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val without initialising it. */
t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val* t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_Alloc();

/* Allocate a tcp_source_TCPSourceListenerNotify without initialising it. */
tcp_source_TCPSourceListenerNotify* tcp_source_TCPSourceListenerNotify_Alloc();

/* Allocate a cluster_manager_DockerSwarmServicesResponseHandler without initialising it. */
cluster_manager_DockerSwarmServicesResponseHandler* cluster_manager_DockerSwarmServicesResponseHandler_Alloc();

/* Allocate a topology_RouterRunner without initialising it. */
topology_RouterRunner* topology_RouterRunner_Alloc();

/* Allocate a collections_HashMap_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val without initialising it. */
collections_HashMap_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val* collections_HashMap_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections_HashIs_boundary_DataReceiversSubscriber_tag_val_Alloc();

/* Allocate a random_MT without initialising it. */
random_MT* random_MT_Alloc();

/* Allocate a network_$33$24_U64_val without initialising it. */
network_$33$24_U64_val* network_$33$24_U64_val_Alloc();

/* Allocate a collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val without initialising it. */
collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val* collections_HashMap_U128_val_U64_val_collections_HashEq_U128_val_val_Alloc();

/* Allocate a routing_$35$72_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val without initialising it. */
routing_$35$72_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val* routing_$35$72_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val_Alloc();

/* Allocate a t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag without initialising it. */
t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag* t2_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_Alloc();

/* Allocate a metrics__MetricsReporter without initialising it. */
metrics__MetricsReporter* metrics__MetricsReporter_Alloc();

/* Allocate a Array_collections_List_time_Timer_ref_ref without initialising it. */
Array_collections_List_time_Timer_ref_ref* Array_collections_List_time_Timer_ref_ref_Alloc();

/* Allocate a initialization_$15$52 without initialising it. */
initialization_$15$52* initialization_$15$52_Alloc();

/* Allocate a u3_t2_U8_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U8_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U8_val_U128_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_val without initialising it. */
collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_val* collections_MapPairs_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_collections_HashMap_String_val_net_TCPConnection_tag_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a u3_tcp_sink_TCPSink_tag_tcp_sink_EmptySink_tag_boundary_OutgoingBoundary_tag without initialising it. */
u3_tcp_sink_TCPSink_tag_tcp_sink_EmptySink_tag_boundary_OutgoingBoundary_tag* u3_tcp_sink_TCPSink_tag_tcp_sink_EmptySink_tag_boundary_OutgoingBoundary_tag_Alloc();

/* Allocate a collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val without initialising it. */
collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val* collections_MapPairs_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a u2_StdinNotify_ref_None_val without initialising it. */
u2_StdinNotify_ref_None_val* u2_StdinNotify_ref_None_val_Alloc();

/* Allocate a u3_t2_String_val_metrics__MetricsReporter_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_metrics__MetricsReporter_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_metrics__MetricsReporter_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u3_t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_boundary_DataReceiversSubscriber_tag_boundary_DataReceiversSubscriber_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_topology_Initializable_tag_None_val without initialising it. */
u2_topology_Initializable_tag_None_val* u2_topology_Initializable_tag_None_val_Alloc();

/* Allocate a Array_u3_t2_String_val_topology_StateSubpartition_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_topology_StateSubpartition_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_topology_StateSubpartition_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_ref without initialising it. */
collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_ref* collections_SetValues_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_collections_HashSet_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_ref_Alloc();

/* Allocate a u6_files_FileOK_val_files_FileError_val_files_FileEOF_val_files_FileBadFileNumber_val_files_FileExists_val_files_FilePermissionDenied_val without initialising it. */
u6_files_FileOK_val_files_FileError_val_files_FileEOF_val_files_FileBadFileNumber_val_files_FileExists_val_files_FilePermissionDenied_val* u6_files_FileOK_val_files_FileError_val_files_FileEOF_val_files_FileBadFileNumber_val_files_FileExists_val_files_FilePermissionDenied_val_Alloc();

/* Allocate a recovery_$37$10 without initialising it. */
recovery_$37$10* recovery_$37$10_Alloc();

/* Allocate a routing_TerminusRoute without initialising it. */
routing_TerminusRoute* routing_TerminusRoute_Alloc();

/* Allocate a collections_HashMap_String_val_U64_val_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_U64_val_collections_HashEq_String_val_val* collections_HashMap_String_val_U64_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a messages_CreateDataChannelListener without initialising it. */
messages_CreateDataChannelListener* messages_CreateDataChannelListener_Alloc();

/* Allocate a u3_t2_USize_val_wallaroo_InitFile_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_USize_val_wallaroo_InitFile_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_USize_val_wallaroo_InitFile_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a messages_ReplayBoundaryCountMsg without initialising it. */
messages_ReplayBoundaryCountMsg* messages_ReplayBoundaryCountMsg_Alloc();

/* Allocate a Array_pony_CPPKey_val without initialising it. */
Array_pony_CPPKey_val* Array_pony_CPPKey_val_Alloc();

/* Allocate a wall_clock_WallClock without initialising it. */
wall_clock_WallClock* wall_clock_WallClock_Alloc();

/* Allocate a collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box without initialising it. */
collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box* collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a topology_KeyedPartitionAddresses_U64_val without initialising it. */
topology_KeyedPartitionAddresses_U64_val* topology_KeyedPartitionAddresses_U64_val_Alloc();

/* Allocate a boundary_$10$17_topology_StateProcessor_pony_CPPState_ref_val without initialising it. */
boundary_$10$17_topology_StateProcessor_pony_CPPState_ref_val* boundary_$10$17_topology_StateProcessor_pony_CPPState_ref_val_Alloc();

/* Allocate a Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag without initialising it. */
Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag* Array_t3_pony_CPPKey_val_U128_val_topology_Step_tag_Alloc();

/* Allocate a Array_U128_val without initialising it. */
Array_U128_val* Array_U128_val_Alloc();

/* Allocate a topology_$36$103_pony_CPPData_val without initialising it. */
topology_$36$103_pony_CPPData_val* topology_$36$103_pony_CPPData_val_Alloc();

/* Allocate a topology_$36$114_pony_CPPData_val_U64_val without initialising it. */
topology_$36$114_pony_CPPData_val_U64_val* topology_$36$114_pony_CPPData_val_U64_val_Alloc();

/* Allocate a ssl__SSLInit without initialising it. */
ssl__SSLInit* ssl__SSLInit_Alloc();

/* Allocate a u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a initialization_$15$67 without initialising it. */
initialization_$15$67* initialization_$15$67_Alloc();

/* Allocate a ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_ref without initialising it. */
ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_ref* ArrayValues_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Array_t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_ref_Alloc();

/* Allocate a collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_val without initialising it. */
collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_val* collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_val_Alloc();

/* Allocate a boundary_$10$27 without initialising it. */
boundary_$10$27* boundary_$10$27_Alloc();

/* Allocate a initialization_$15$62 without initialising it. */
initialization_$15$62* initialization_$15$62_Alloc();

/* Allocate a files_FileEOF without initialising it. */
files_FileEOF* files_FileEOF_Alloc();

/* Allocate a messages_CreateConnectionsMsg without initialising it. */
messages_CreateConnectionsMsg* messages_CreateConnectionsMsg_Alloc();

/* Allocate a ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_box without initialising it. */
ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_box* ArrayValues_t2_pony_CPPKey_val_USize_val_Array_t2_pony_CPPKey_val_USize_val_box_Alloc();

/* Allocate a topology_$36$113_pony_CPPData_val_U64_val without initialising it. */
topology_$36$113_pony_CPPData_val_U64_val* topology_$36$113_pony_CPPData_val_U64_val_Alloc();

/* Allocate a messages_ReconnectDataPortMsg without initialising it. */
messages_ReconnectDataPortMsg* messages_ReconnectDataPortMsg_Alloc();

/* Allocate a t2_options__Option_ref_USize_val without initialising it. */
t2_options__Option_ref_USize_val* t2_options__Option_ref_USize_val_Alloc();

/* Allocate a fail_Fail without initialising it. */
fail_Fail* fail_Fail_Alloc();

/* Allocate a u2_t2_U128_val_topology_SourceData_val_None_val without initialising it. */
u2_t2_U128_val_topology_SourceData_val_None_val* u2_t2_U128_val_topology_SourceData_val_None_val_Alloc();

/* Allocate a topology_$36$119_U8_val without initialising it. */
topology_$36$119_U8_val* topology_$36$119_U8_val_Alloc();

/* Allocate a topology_DirectRouter without initialising it. */
topology_DirectRouter* topology_DirectRouter_Alloc();

/* Allocate a http_URLPartHost without initialising it. */
http_URLPartHost* http_URLPartHost_Alloc();

/* Allocate a ArrayValues_options__Option_ref_Array_options__Option_ref_val without initialising it. */
ArrayValues_options__Option_ref_Array_options__Option_ref_val* ArrayValues_options__Option_ref_Array_options__Option_ref_val_Alloc();

/* Allocate a collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_val without initialising it. */
collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_val* collections_MapPairs_U64_val_U128_val_collections_HashEq_U64_val_val_collections_HashMap_U64_val_U128_val_collections_HashEq_U64_val_val_val_Alloc();

/* Allocate a files_FileMode without initialising it. */
files_FileMode* files_FileMode_Alloc();

/* Allocate a Array_u3_t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_ref without initialising it. */
collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_ref* collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_ref_Alloc();

/* Allocate a collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val without initialising it. */
collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val* collections_MapPairs_String_val_U128_val_collections_HashEq_String_val_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a _ToString without initialising it. */
_ToString* _ToString_Alloc();

/* Allocate a t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val without initialising it. */
t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val* t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_val_Alloc();

/* Allocate a pony_CPPStateChangeRepositoryHelper without initialising it. */
pony_CPPStateChangeRepositoryHelper* pony_CPPStateChangeRepositoryHelper_Alloc();

pony_CPPStateComputationReturnPairWrapper* pony_CPPStateChangeRepositoryHelper_get_stateful_computation_return(pony_CPPStateChangeRepositoryHelper* self, char* data, void* state_change);

pony_CPPStateChangeRepositoryHelper* pony_CPPStateChangeRepositoryHelper_create(pony_CPPStateChangeRepositoryHelper* self);

void* pony_CPPStateChangeRepositoryHelper_lookup_by_name(pony_CPPStateChangeRepositoryHelper* self, topology_StateChangeRepository_pony_CPPState_ref* sc_repo, char* name_p);

bool pony_CPPStateChangeRepositoryHelper_ne(pony_CPPStateChangeRepositoryHelper* self, pony_CPPStateChangeRepositoryHelper* that);

bool pony_CPPStateChangeRepositoryHelper_eq(pony_CPPStateChangeRepositoryHelper* self, pony_CPPStateChangeRepositoryHelper* that);

char* pony_CPPStateChangeRepositoryHelper_get_state_change_object(pony_CPPStateChangeRepositoryHelper* self, pony_CPPStateChange* state_change);

/* Allocate a u3_t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a network_$33$25 without initialising it. */
network_$33$25* network_$33$25_Alloc();

/* Allocate a collections_HashIs_time_Timer_tag without initialising it. */
collections_HashIs_time_Timer_tag* collections_HashIs_time_Timer_tag_Alloc();

/* Allocate a u2_http_Payload_val_None_val without initialising it. */
u2_http_Payload_val_None_val* u2_http_Payload_val_None_val_Alloc();

/* Allocate a u3_Array_String_val_val_topology_ProxyAddress_val_topology_PartitionAddresses_val without initialising it. */
u3_Array_String_val_val_topology_ProxyAddress_val_topology_PartitionAddresses_val* u3_Array_String_val_val_topology_ProxyAddress_val_topology_PartitionAddresses_val_Alloc();

/* Allocate a tcp_sink_$41$6_pony_CPPData_val without initialising it. */
tcp_sink_$41$6_pony_CPPData_val* tcp_sink_$41$6_pony_CPPData_val_Alloc();

/* Allocate a t2_U128_val_U64_val without initialising it. */
t2_U128_val_U64_val* t2_U128_val_U64_val_Alloc();

/* Allocate a collections_HashMap_time_Timer_tag_time_Timer_ref_collections_HashIs_time_Timer_tag_val without initialising it. */
collections_HashMap_time_Timer_tag_time_Timer_ref_collections_HashIs_time_Timer_tag_val* collections_HashMap_time_Timer_tag_time_Timer_ref_collections_HashIs_time_Timer_tag_val_Alloc();

/* Allocate a u4_options_UnrecognisedOption_val_options_MissingArgument_val_options_InvalidArgument_val_options_AmbiguousMatch_val without initialising it. */
u4_options_UnrecognisedOption_val_options_MissingArgument_val_options_InvalidArgument_val_options_AmbiguousMatch_val* u4_options_UnrecognisedOption_val_options_MissingArgument_val_options_InvalidArgument_val_options_AmbiguousMatch_val_Alloc();

/* Allocate a t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref without initialising it. */
t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref* t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_Alloc();

/* Allocate a collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref without initialising it. */
collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref* collections_MapKeys_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_collections_HashMap_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections_HashEq_U128_val_val_ref_Alloc();

/* Allocate a collections_HashMap_topology_Step_tag_topology_Step_tag_collections_HashIs_topology_Step_tag_val without initialising it. */
collections_HashMap_topology_Step_tag_topology_Step_tag_collections_HashIs_topology_Step_tag_val* collections_HashMap_topology_Step_tag_topology_Step_tag_collections_HashIs_topology_Step_tag_val_Alloc();

/* Allocate a routing_DummyConsumer without initialising it. */
routing_DummyConsumer* routing_DummyConsumer_Alloc();

/* Allocate a t2_String_val_u4_None_val_String_val_I64_val_F64_val without initialising it. */
t2_String_val_u4_None_val_String_val_I64_val_F64_val* t2_String_val_u4_None_val_String_val_I64_val_F64_val_Alloc();

/* Allocate a u3_t2_time_Timer_tag_time_Timer_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_time_Timer_tag_time_Timer_ref_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_time_Timer_tag_time_Timer_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a u2_u2_topology_Step_tag_topology_ProxyRouter_val_None_val without initialising it. */
u2_u2_topology_Step_tag_topology_ProxyRouter_val_None_val* u2_u2_topology_Step_tag_topology_ProxyRouter_val_None_val_Alloc();

/* Allocate a recovery_$37$11 without initialising it. */
recovery_$37$11* recovery_$37$11_Alloc();

/* Allocate a topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_U8_val_pony_CPPState_ref without initialising it. */
topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_U8_val_pony_CPPState_ref* topology_PreStateRunnerBuilder_pony_CPPData_val_pony_CPPData_val_pony_CPPData_val_U8_val_pony_CPPState_ref_Alloc();

/* Allocate a boundary_BoundaryNotify without initialising it. */
boundary_BoundaryNotify* boundary_BoundaryNotify_Alloc();

/* Allocate a u4_None_val_String_val_I64_val_F64_val without initialising it. */
u4_None_val_String_val_I64_val_F64_val* u4_None_val_String_val_I64_val_F64_val_Alloc();

/* Allocate a collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_box without initialising it. */
collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_box* collections_MapPairs_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections_HashEq_pony_CPPKey_val_val_box_Alloc();

/* Allocate a t2_U32_val_Pointer_Pointer_U8_val_tag_tag without initialising it. */
t2_U32_val_Pointer_Pointer_U8_val_tag_tag* t2_U32_val_Pointer_Pointer_U8_val_tag_tag_Alloc();

/* Allocate a net_DNSAuth without initialising it. */
net_DNSAuth* net_DNSAuth_Alloc();

/* Allocate a t2_String_val_topology_PartitionAddresses_val without initialising it. */
t2_String_val_topology_PartitionAddresses_val* t2_String_val_topology_PartitionAddresses_val_Alloc();

/* Allocate a ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_box without initialising it. */
ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_box* ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_box_Alloc();

/* Allocate a u3_t2_U128_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U128_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U128_val_U64_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a messages_KeyedStepMigrationMsg_U64_val without initialising it. */
messages_KeyedStepMigrationMsg_U64_val* messages_KeyedStepMigrationMsg_U64_val_Alloc();

/* Allocate a hub_HubProtocol without initialising it. */
hub_HubProtocol* hub_HubProtocol_Alloc();

/* Allocate a u3_t2_routing_Consumer_tag_routing_Route_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_routing_Consumer_tag_routing_Route_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_routing_Consumer_tag_routing_Route_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a pony_$2$8 without initialising it. */
pony_$2$8* pony_$2$8_Alloc();

/* Allocate a collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_box without initialising it. */
collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_box* collections_SetValues_String_val_collections_HashEq_String_val_val_collections_HashSet_String_val_collections_HashEq_String_val_val_box_Alloc();

/* Allocate a tcp_source__SourceBuilder_pony_CPPData_val without initialising it. */
tcp_source__SourceBuilder_pony_CPPData_val* tcp_source__SourceBuilder_pony_CPPData_val_Alloc();

/* Allocate a http_ResponseHandler without initialising it. */
http_ResponseHandler* http_ResponseHandler_Alloc();

/* Allocate a messages1_ExternalMsgEncoder without initialising it. */
messages1_ExternalMsgEncoder* messages1_ExternalMsgEncoder_Alloc();

/* Allocate a wallaroo_InitFile without initialising it. */
wallaroo_InitFile* wallaroo_InitFile_Alloc();

/* Allocate a u3_t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a topology_Partition_pony_CPPData_val_U64_val without initialising it. */
topology_Partition_pony_CPPData_val_U64_val* topology_Partition_pony_CPPData_val_U64_val_Alloc();

/* Allocate a u4_files__PathSep_val_files__PathDot_val_files__PathDot2_val_files__PathOther_val without initialising it. */
u4_files__PathSep_val_files__PathDot_val_files__PathDot2_val_files__PathOther_val* u4_files__PathSep_val_files__PathDot_val_files__PathDot2_val_files__PathOther_val_Alloc();

/* Allocate a net_IPAddress without initialising it. */
net_IPAddress* net_IPAddress_Alloc();

/* Allocate a files_FilePermissionDenied without initialising it. */
files_FilePermissionDenied* files_FilePermissionDenied_Alloc();

/* Allocate a routing_$35$15 without initialising it. */
routing_$35$15* routing_$35$15_Alloc();

/* Allocate a u3_t2_U8_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U8_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U8_val_topology_ProxyAddress_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a Array_tcp_sink_TCPSink_tag without initialising it. */
Array_tcp_sink_TCPSink_tag* Array_tcp_sink_TCPSink_tag_Alloc();

/* Allocate a t2_boundary__BoundaryId_val_boundary_DataReceiver_tag without initialising it. */
t2_boundary__BoundaryId_val_boundary_DataReceiver_tag* t2_boundary__BoundaryId_val_boundary_DataReceiver_tag_Alloc();

/* Allocate a u2_topology_Step_tag_topology_ProxyRouter_val without initialising it. */
u2_topology_Step_tag_topology_ProxyRouter_val* u2_topology_Step_tag_topology_ProxyRouter_val_Alloc();

/* Allocate a time__ClockRealtime without initialising it. */
time__ClockRealtime* time__ClockRealtime_Alloc();

/* Allocate a routing_$35$95 without initialising it. */
routing_$35$95* routing_$35$95_Alloc();

/* Allocate a collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val* collections_HashMap_String_val_boundary_OutgoingBoundaryBuilder_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val without initialising it. */
collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val* collections_HashMap_U128_val_String_val_collections_HashEq_U128_val_val_Alloc();

/* Allocate a t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val without initialising it. */
t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val* t2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Alloc();

/* Allocate a collections_HashMap_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections_HashIs_data_channel_DataChannelListener_tag_val without initialising it. */
collections_HashMap_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections_HashIs_data_channel_DataChannelListener_tag_val* collections_HashMap_data_channel_DataChannelListener_tag_data_channel_DataChannelListener_tag_collections_HashIs_data_channel_DataChannelListener_tag_val_Alloc();

/* Allocate a data_channel_$45$9 without initialising it. */
data_channel_$45$9* data_channel_$45$9_Alloc();

/* Allocate a cluster_manager_DockerSwarmClusterManager without initialising it. */
cluster_manager_DockerSwarmClusterManager* cluster_manager_DockerSwarmClusterManager_Alloc();

/* Allocate a pony_CPPComputationBuilder without initialising it. */
pony_CPPComputationBuilder* pony_CPPComputationBuilder_Alloc();

/* Allocate a collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val without initialising it. */
collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val* collections_HashMap_U8_val_U128_val_collections_HashEq_U8_val_val_Alloc();

/* Allocate a routing_EmptyRoute without initialising it. */
routing_EmptyRoute* routing_EmptyRoute_Alloc();

/* Allocate a messages_JoinClusterMsg without initialising it. */
messages_JoinClusterMsg* messages_JoinClusterMsg_Alloc();

/* Allocate a data_channel_$45$6 without initialising it. */
data_channel_$45$6* data_channel_$45$6_Alloc();

/* Allocate a $0$13_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag without initialising it. */
$0$13_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag* $0$13_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_Alloc();

/* Allocate a collections_HashMap_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val without initialising it. */
collections_HashMap_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val* collections_HashMap_tcp_source_TCPSource_tag_tcp_source_TCPSource_tag_collections_HashIs_tcp_source_TCPSource_tag_val_Alloc();

/* Allocate a routing_EmptyRouteBuilder without initialising it. */
routing_EmptyRouteBuilder* routing_EmptyRouteBuilder_Alloc();

/* Allocate a messages_AnnounceNewStatefulStepMsg without initialising it. */
messages_AnnounceNewStatefulStepMsg* messages_AnnounceNewStatefulStepMsg_Alloc();

/* Allocate a Array_u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_String_val_collections_HashMap_String_val_U128_val_collections_HashEq_String_val_val_ref_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a metrics_MetricsMonitor without initialising it. */
metrics_MetricsMonitor* metrics_MetricsMonitor_Alloc();

/* Allocate a u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_collections_HashSet_U128_val_collections_HashIs_U128_val_val_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a boundary_$10$18_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val without initialising it. */
boundary_$10$18_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val* boundary_$10$18_topology_StateComputationWrapper_pony_CPPData_val_pony_CPPData_val_pony_CPPState_ref_val_Alloc();

/* Allocate a Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref without initialising it. */
Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref* Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Alloc();

/* Allocate a initialization_InitFileReader without initialising it. */
initialization_InitFileReader* initialization_InitFileReader_Alloc();

/* Allocate a ArrayValues_String_val_Array_String_val_ref without initialising it. */
ArrayValues_String_val_Array_String_val_ref* ArrayValues_String_val_Array_String_val_ref_Alloc();

/* Allocate a t2_U128_val_topology_Router_val without initialising it. */
t2_U128_val_topology_Router_val* t2_U128_val_topology_Router_val_Alloc();

/* Allocate a collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_box without initialising it. */
collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_box* collections_MapValues_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_box_Alloc();

/* Allocate a network_$33$35 without initialising it. */
network_$33$35* network_$33$35_Alloc();

/* Allocate a routing_Producer without initialising it. */
routing_Producer* routing_Producer_Alloc();

/* Allocate a topology_OmniRouter without initialising it. */
topology_OmniRouter* topology_OmniRouter_Alloc();

/* Allocate a u2_collections_ListNode_http_Payload_val_ref_None_val without initialising it. */
u2_collections_ListNode_http_Payload_val_ref_None_val* u2_collections_ListNode_http_Payload_val_ref_None_val_Alloc();

/* Allocate a files__PathDot without initialising it. */
files__PathDot* files__PathDot_Alloc();

/* Allocate a ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_ref without initialising it. */
ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_ref* ArrayValues_Array_U8_val_ref_Array_Array_U8_val_ref_ref_Alloc();

/* Allocate a u2_None_val_wallaroo_Application_ref without initialising it. */
u2_None_val_wallaroo_Application_ref* u2_None_val_wallaroo_Application_ref_Alloc();

/* Allocate a t2_ISize_val_String_val without initialising it. */
t2_ISize_val_String_val* t2_ISize_val_String_val_Alloc();

/* Allocate a u2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_None_val without initialising it. */
u2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_None_val* u2_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_None_val_Alloc();

/* Allocate a collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_ref without initialising it. */
collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_ref* collections_MapPairs_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_collections_HashMap_U128_val_u2_topology_ProxyAddress_val_U128_val_collections_HashEq_U128_val_val_ref_Alloc();

/* Allocate a collections_HashMap_String_val_topology_PartitionAddresses_val_collections_HashEq_String_val_val without initialising it. */
collections_HashMap_String_val_topology_PartitionAddresses_val_collections_HashEq_String_val_val* collections_HashMap_String_val_topology_PartitionAddresses_val_collections_HashEq_String_val_val_Alloc();

/* Allocate a messages_ChannelMsgEncoder without initialising it. */
messages_ChannelMsgEncoder* messages_ChannelMsgEncoder_Alloc();

/* Allocate a topology_$36$121 without initialising it. */
topology_$36$121* topology_$36$121_Alloc();

/* Allocate a files_FileRead without initialising it. */
files_FileRead* files_FileRead_Alloc();

/* Allocate a time__ClockMonotonic without initialising it. */
time__ClockMonotonic* time__ClockMonotonic_Alloc();

/* Allocate a i2_ReadSeq_U8_val_box_ReadElement_U8_val_box without initialising it. */
i2_ReadSeq_U8_val_box_ReadElement_U8_val_box* i2_ReadSeq_U8_val_box_ReadElement_U8_val_box_Alloc();

/* Allocate a network_ControlChannelConnectNotifier without initialising it. */
network_ControlChannelConnectNotifier* network_ControlChannelConnectNotifier_Alloc();

/* Allocate a t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val without initialising it. */
t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val* t6_U128_val_U128_val_None_val_U64_val_U64_val_u2_String_val_Array_U8_val_val_Alloc();

/* Allocate a u3_t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_U128_val_i3_topology_RunnableStep_tag_routing_Consumer_tag_topology_Initializable_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_box without initialising it. */
collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_box* collections_MapPairs_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_collections_HashMap_U128_val_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_collections_HashEq_U128_val_val_box_Alloc();

/* Allocate a collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_box without initialising it. */
collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_box* collections_MapPairs_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_collections_HashMap_pony_CPPKey_val_U128_val_collections_HashEq_pony_CPPKey_val_val_box_Alloc();

/* Allocate a recovery_$37$24 without initialising it. */
recovery_$37$24* recovery_$37$24_Alloc();

/* Allocate a topology_$36$114_pony_CPPData_val_U8_val without initialising it. */
topology_$36$114_pony_CPPData_val_U8_val* topology_$36$114_pony_CPPData_val_U8_val_Alloc();

/* Allocate a u3_metrics_ComputationCategory_val_metrics_StartToEndCategory_val_metrics_NodeIngressEgressCategory_val without initialising it. */
u3_metrics_ComputationCategory_val_metrics_StartToEndCategory_val_metrics_NodeIngressEgressCategory_val* u3_metrics_ComputationCategory_val_metrics_StartToEndCategory_val_metrics_NodeIngressEgressCategory_val_Alloc();

/* Allocate a Array_u3_t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_U8_val_u2_topology_Step_tag_topology_ProxyRouter_val_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a recovery_$37$28 without initialising it. */
recovery_$37$28* recovery_$37$28_Alloc();

/* Allocate a u2_topology_Router_val_None_val without initialising it. */
u2_topology_Router_val_None_val* u2_topology_Router_val_None_val_Alloc();

/* Allocate a u2_t2_String_val_u4_None_val_String_val_I64_val_F64_val_options_ParseError_ref without initialising it. */
u2_t2_String_val_u4_None_val_String_val_I64_val_F64_val_options_ParseError_ref* u2_t2_String_val_u4_None_val_String_val_I64_val_F64_val_options_ParseError_ref_Alloc();

/* Allocate a routing_$35$75_pony_CPPData_val_pony_CPPData_val without initialising it. */
routing_$35$75_pony_CPPData_val_pony_CPPData_val* routing_$35$75_pony_CPPData_val_pony_CPPData_val_Alloc();

/* Allocate a boundary_$10$26 without initialising it. */
boundary_$10$26* boundary_$10$26_Alloc();

/* Allocate a recovery_$37$15 without initialising it. */
recovery_$37$15* recovery_$37$15_Alloc();

/* Allocate a Array_u3_t2_topology_Step_tag_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
Array_u3_t2_topology_Step_tag_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val* Array_u3_t2_topology_Step_tag_topology_Step_tag_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a collections_HashIs_net_TCPListener_tag without initialising it. */
collections_HashIs_net_TCPListener_tag* collections_HashIs_net_TCPListener_tag_Alloc();

/* Allocate a t5_routing_Producer_tag_U128_val_None_val_U64_val_U64_val without initialising it. */
t5_routing_Producer_tag_U128_val_None_val_U64_val_U64_val* t5_routing_Producer_tag_U128_val_None_val_U64_val_U64_val_Alloc();

/* Allocate a t2_collections_ListNode_time_Timer_ref_ref_collections_ListNode_time_Timer_ref_ref without initialising it. */
t2_collections_ListNode_time_Timer_ref_ref_collections_ListNode_time_Timer_ref_ref* t2_collections_ListNode_time_Timer_ref_ref_collections_ListNode_time_Timer_ref_ref_Alloc();

/* Allocate a ReadElement_U8_val without initialising it. */
ReadElement_U8_val* ReadElement_U8_val_Alloc();

/* Allocate a initialization_$15$53 without initialising it. */
initialization_$15$53* initialization_$15$53_Alloc();

/* Allocate a ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_box without initialising it. */
ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_box* ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_ref_box_Alloc();

/* Allocate a collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_box without initialising it. */
collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_box* collections_MapValues_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_collections_HashMap_routing_Consumer_tag_routing_Route_ref_collections_HashIs_routing_Consumer_tag_val_box_Alloc();

/* Allocate a serialise_Serialised without initialising it. */
serialise_Serialised* serialise_Serialised_Alloc();

/* Allocate a topology_$36$130 without initialising it. */
topology_$36$130* topology_$36$130_Alloc();

/* Allocate a topology_SourceData without initialising it. */
topology_SourceData* topology_SourceData_Alloc();

/* Allocate a time__TimingWheel without initialising it. */
time__TimingWheel* time__TimingWheel_Alloc();

/* Allocate a boundary__EmptyTimerInit without initialising it. */
boundary__EmptyTimerInit* boundary__EmptyTimerInit_Alloc();

/* Allocate a Array_USize_val without initialising it. */
Array_USize_val* Array_USize_val_Alloc();

/* Allocate a topology_$36$127 without initialising it. */
topology_$36$127* topology_$36$127_Alloc();

/* Allocate a ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_val without initialising it. */
ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_val* ArrayValues_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_Array_dag_DagNode_u3_topology_StepBuilder_val_topology_SourceData_val_topology_EgressBuilder_val_val_val_Alloc();

/* Allocate a initialization_$15$71 without initialising it. */
initialization_$15$71* initialization_$15$71_Alloc();

/* Allocate a messages1_ExternalStartGilesSendersMsg without initialising it. */
messages1_ExternalStartGilesSendersMsg* messages1_ExternalStartGilesSendersMsg_Alloc();

/* Allocate a rebalancing_PartitionRebalancer without initialising it. */
rebalancing_PartitionRebalancer* rebalancing_PartitionRebalancer_Alloc();

/* Allocate a Array_wallaroo_BasicPipeline_ref without initialising it. */
Array_wallaroo_BasicPipeline_ref* Array_wallaroo_BasicPipeline_ref_Alloc();

/* Allocate a u2_t2_u2_String_val_Array_U8_val_val_USize_val_None_val without initialising it. */
u2_t2_u2_String_val_Array_U8_val_val_USize_val_None_val* u2_t2_u2_String_val_Array_U8_val_val_USize_val_None_val_Alloc();

/* Allocate a t2_I64_val_I64_val without initialising it. */
t2_I64_val_I64_val* t2_I64_val_I64_val_Alloc();

/* Allocate a u2_Array_topology_PreStateData_val_val_None_val without initialising it. */
u2_Array_topology_PreStateData_val_val_None_val* u2_Array_topology_PreStateData_val_val_None_val_Alloc();

/* Allocate a messages1_ExternalShutdownMsg without initialising it. */
messages1_ExternalShutdownMsg* messages1_ExternalShutdownMsg_Alloc();

/* Allocate a ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_val without initialising it. */
ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_val* ArrayValues_t3_U8_val_U128_val_topology_Step_tag_Array_t3_U8_val_U128_val_topology_Step_tag_val_Alloc();

/* Allocate a u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val without initialising it. */
u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val* u3_t2_String_val_collections_HashMap_String_val_t2_String_val_String_val_collections_HashEq_String_val_val_box_collections__MapEmpty_val_collections__MapDeleted_val_Alloc();

/* Allocate a Env without initialising it. */
Env* Env_Alloc();

/* Allocate a collections_HashIs_topology_Initializable_tag without initialising it. */
collections_HashIs_topology_Initializable_tag* collections_HashIs_topology_Initializable_tag_Alloc();


#ifdef __cplusplus
}
#endif

#endif
