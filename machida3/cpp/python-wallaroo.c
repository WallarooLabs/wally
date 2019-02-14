/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

#include <Python.h>


PyObject *g_user_deserialization_fn;
PyObject *g_user_serialization_fn;

extern PyObject *load_module(char *module_name)
{
  PyObject *pName, *pModule;

  pName = PyUnicode_FromString(module_name);
  /* Error checking of pName left out */

  pModule = PyImport_Import(pName);
  Py_DECREF(pName);

  return pModule;
}

extern PyObject *application_setup(PyObject *pModule, PyObject *args)
{
  PyObject *pFunc, *pValue;

  pFunc = PyObject_GetAttrString(pModule, "application_setup");
  pValue = PyObject_CallFunctionObjArgs(pFunc, args, NULL);
  Py_DECREF(pFunc);

  return pValue;
}

extern size_t list_item_count(PyObject *list)
{
  return PyList_Size(list);
}

extern PyObject *get_application_setup_item(PyObject *list, size_t idx)
{
  return PyList_GetItem(list, idx);
}

extern char *get_application_setup_action(PyObject *item)
{
  PyObject *action = PyTuple_GetItem(item, 0);

  char * rtn = PyUnicode_AsUTF8(action);
  Py_DECREF(action);
  return rtn;
}

extern PyObject *get_list_item(PyObject *list, size_t idx)
{
  return PyList_GetItem(list, idx);
}

extern char *get_stage_command(PyObject *item)
{
  printf("!@ get_stage_command");
  PyObject *command = PyTuple_GetItem(item, 0);
  char * rtn = PyBytes_AsString(command);
  printf("!@ get_stage_command:got string");
  Py_DECREF(command);
  return rtn;
}

extern size_t source_decoder_header_length(PyObject *source_decoder)
{
  PyObject *pFunc, *pValue;

  pFunc = PyObject_GetAttrString(source_decoder, "header_length");
  pValue = PyObject_CallFunctionObjArgs(pFunc, NULL);

  size_t sz = PyLong_AsSsize_t(pValue);
  Py_XDECREF(pFunc);
  Py_DECREF(pValue);
  if (sz > 0 && sz < SIZE_MAX) {
    return sz;
  } else {
    return 0;
  }
}

extern size_t source_decoder_payload_length(PyObject *source_decoder, char *bytes, size_t size)
{
  PyObject *pFunc, *pValue, *pBytes;

  pFunc = PyObject_GetAttrString(source_decoder, "payload_length");
  pBytes = PyBytes_FromStringAndSize(bytes, size);
  pValue = PyObject_CallFunctionObjArgs(pFunc, pBytes, NULL);

  size_t sz = PyLong_AsSsize_t(pValue);

  Py_XDECREF(pFunc);
  Py_XDECREF(pBytes);
  Py_XDECREF(pValue);

  /*
  ** NOTE: This doesn't protect us from Python from returning
  **       something bogus like -7.  There is no Python/C API
  **       function to tell us if the Python value is negative.
  */
  if (sz > 0 && sz < SIZE_MAX) {
    return sz;
  } else {
    printf("ERROR: Python payload_length() method returned invalid size\n");
    return 0;
  }
}

extern PyObject *source_decoder_decode(PyObject *source_decoder, char *bytes, size_t size)
{
  PyObject *pFunc, *pBytes, *pValue;

  pFunc = PyObject_GetAttrString(source_decoder, "decode");
  pBytes = PyBytes_FromStringAndSize(bytes, size);
  pValue = PyObject_CallFunctionObjArgs(pFunc, pBytes, NULL);

  Py_DECREF(pFunc);
  Py_DECREF(pBytes);

  return pValue;
}

extern PyObject *source_generator_initial_value(PyObject *source_generator)
{
  PyObject *pFunc, *pValue;

  pFunc = PyObject_GetAttrString(source_generator, "initial_value");
  pValue = PyObject_CallFunctionObjArgs(pFunc,  NULL);
  Py_DECREF(pFunc);

  return pValue;
}

extern PyObject *source_generator_apply(PyObject *source_generator, PyObject *data)
{
  PyObject *pFunc, *pValue;

  pFunc = PyObject_GetAttrString(source_generator, "apply");
  pValue = PyObject_CallFunctionObjArgs(pFunc, data, NULL);
  Py_DECREF(pFunc);

  return pValue;
}

extern PyObject *instantiate_python_class(PyObject *class)
{
  return PyObject_CallFunctionObjArgs(class, NULL);
}

extern PyObject *get_name(PyObject *pObject)
{
  PyObject *pFunc, *pValue = NULL;

  pFunc = PyObject_GetAttrString(pObject, "name");
  if (pFunc != NULL) {
    pValue = PyObject_CallFunctionObjArgs(pFunc, NULL);
    Py_DECREF(pFunc);
  }

  return pValue;
}

extern PyObject *computation_compute(PyObject *computation, PyObject *data,
  char* method)
{
  PyObject *pFunc, *pValue;

  pFunc = PyObject_GetAttrString(computation, method);
  pValue = PyObject_CallFunctionObjArgs(pFunc, data, NULL);
  Py_DECREF(pFunc);

  return pValue;
}

extern PyObject *sink_encoder_encode(PyObject *sink_encoder, PyObject *data)
{
  PyObject *pFunc, *pValue;

  pFunc = PyObject_GetAttrString(sink_encoder, "encode");
  pValue = PyObject_CallFunctionObjArgs(pFunc, data, NULL);

  Py_DECREF(pFunc);
  return pValue;
}

extern void py_incref(PyObject *o)
{
  Py_INCREF(o);
}

extern void py_decref(PyObject *o)
{
  Py_DECREF(o);
}

extern PyObject *stateful_computation_compute(PyObject *computation,
  PyObject *data, PyObject *state, char *method)
{
  PyObject *pFunc, *pValue;

  pFunc = PyObject_GetAttrString(computation, method);
  pValue = PyObject_CallFunctionObjArgs(pFunc, data, state, NULL);
  Py_DECREF(pFunc);

  return pValue;
}

extern PyObject *initial_state(PyObject *computation)
{
  PyObject *pFunc, *pState;

  pFunc = PyObject_GetAttrString(computation, "initial_state");
  pState = PyObject_CallFunctionObjArgs(pFunc, NULL);
  Py_DECREF(pFunc);

  return pState;
}

extern PyObject *initial_accumulator(PyObject *aggregation)
{
  PyObject *pFunc, *pState;

  pFunc = PyObject_GetAttrString(aggregation, "initial_accumulator");
  pState = PyObject_CallFunctionObjArgs(pFunc, NULL);
  Py_DECREF(pFunc);

  return pState;
}

extern void aggregation_update(PyObject *aggregation, PyObject *data, PyObject *acc)
{
  PyObject *pFunc, *pState;

  pFunc = PyObject_GetAttrString(aggregation, "update");
  PyObject_CallFunctionObjArgs(pFunc, data, acc, NULL);
  Py_DECREF(pFunc);
}

extern PyObject *aggregation_combine(PyObject *aggregation, PyObject *acc1, PyObject *acc2)
{
  PyObject *pFunc, *pState;

  pFunc = PyObject_GetAttrString(aggregation, "combine");
  pState = PyObject_CallFunctionObjArgs(pFunc, acc1, acc2, NULL);
  Py_DECREF(pFunc);

  return pState;
}

extern PyObject *aggregation_output(PyObject *aggregation, char *key, PyObject *acc)
{
  PyObject *pFunc, *pData, *pKey;

  pKey = PyUnicode_FromString(key);

  pFunc = PyObject_GetAttrString(aggregation, "output");
  pData = PyObject_CallFunctionObjArgs(pFunc, pKey, acc, NULL);
  Py_DECREF(pKey);
  Py_DECREF(pFunc);

  return pData;
}

extern long key_hash(PyObject *key)
{
  return PyObject_Hash(key);
}


extern int key_eq(PyObject *key, PyObject* other)
{
  return PyObject_RichCompareBool(key, other, Py_EQ);
}

extern PyObject *extract_key(PyObject *key_extractor, PyObject *data)
{
  PyObject *pFunc, *pValue;

  pFunc = PyObject_GetAttrString(key_extractor, "extract_key");
  pValue = PyObject_CallFunctionObjArgs(pFunc, data, NULL);
  Py_DECREF(pFunc);

  return pValue;
}

extern int set_command_line_args(PyObject *module, PyObject *tuple)
{
  PyObject *wallaroo = PyObject_GetAttrString(module, "wallaroo");
  int result = PyObject_SetAttrString(wallaroo, "_ARGS", tuple);
  Py_DECREF(wallaroo);
  return result;
}

extern void set_user_serialization_fns(PyObject *module)
{
  if (PyObject_HasAttrString(module, "deserialize") && PyObject_HasAttrString(module, "serialize"))
  {
    g_user_deserialization_fn = PyObject_GetAttrString(module, "deserialize");
    g_user_serialization_fn = PyObject_GetAttrString(module, "serialize");
  }
  else
  {
    PyObject *wallaroo = PyObject_GetAttrString(module, "wallaroo");
    g_user_deserialization_fn = PyObject_GetAttrString(wallaroo, "deserialize");
    g_user_serialization_fn = PyObject_GetAttrString(wallaroo, "serialize");
    Py_DECREF(wallaroo);
  }
}

extern void *user_deserialization(char *bytes)
{
  unsigned char *ubytes = (unsigned char *)bytes;
  // extract size
  size_t size = (((size_t)ubytes[0]) << 24)
    + (((size_t)ubytes[1]) << 16)
    + (((size_t)ubytes[2]) << 8)
    + ((size_t)ubytes[3]);

  PyObject *py_bytes = PyBytes_FromStringAndSize(bytes + 4, size);
  PyObject *ret = PyObject_CallFunctionObjArgs(g_user_deserialization_fn, py_bytes, NULL);

  Py_DECREF(py_bytes);

  return ret;
}

extern size_t user_serialization_get_size(PyObject *o)
{
  PyObject *user_bytes = PyObject_CallFunctionObjArgs(g_user_serialization_fn, o, NULL);

  // This will be null if there was an exception.
  if (user_bytes)
  {
    size_t size = PyBytes_Size(user_bytes);
    Py_DECREF(user_bytes);

    // return the size of the buffer plus the 4 bytes needed to record that size.
    return 4 + size;
  }

  return 0;
}

extern void user_serialization(PyObject *o, char *bytes)
{
  PyObject *user_bytes = PyObject_CallFunctionObjArgs(g_user_serialization_fn, o, NULL);

  // This will be null if there was an exception.
  if (user_bytes)
  {
    size_t size = PyBytes_Size(user_bytes);

    unsigned char *ubytes = (unsigned char *) bytes;

    ubytes[0] = (unsigned char)(size >> 24);
    ubytes[1] = (unsigned char)(size >> 16);
    ubytes[2] = (unsigned char)(size >> 8);
    ubytes[3] = (unsigned char)(size);

    memcpy(bytes + 4, PyBytes_AsString(user_bytes), size);

    Py_DECREF(user_bytes);
  }
}

extern int py_bool_check(PyObject *b)
{
  return PyBool_Check(b);
}

extern int is_py_none(PyObject *o)
{
  return o == Py_None;
}

extern int py_list_check(PyObject *l)
{
  return PyList_Check(l);
}

extern int py_tuple_check(PyObject *t)
{
  return PyTuple_Check(t);
}

extern int py_unicode_check(PyObject *o)
{
  return PyUnicode_Check(o);
}

extern int py_bytes_check(PyObject *o)
{
  return PyBytes_Check(o);
}

extern size_t py_bytes_or_unicode_size(PyObject *o)
{
  if (PyBytes_Check(o)) {
    return PyBytes_Size(o);
  } else if (PyUnicode_Check(o)) {
    return PyUnicode_GetLength(o);
  }
}

extern char *py_bytes_or_unicode_as_char(PyObject *o)
{
  if (PyBytes_Check(o)) {
    return PyBytes_AsString(o);
  } else if (PyUnicode_Check(o)) {
    return PyUnicode_AsUTF8(o);
  } else{
    return NULL;
  }
}
