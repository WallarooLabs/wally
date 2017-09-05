/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

#ifdef __APPLE__
    #include <Python/Python.h>
#else
    #include <python2.7/Python.h>
#endif


PyObject *g_user_deserialization_fn;
PyObject *g_user_serialization_fn;

extern void py_incref(PyObject *o)
{
  Py_INCREF(o);
}

extern void py_decref(PyObject *o)
{
  Py_DECREF(o);
}

extern size_t list_item_count(PyObject *list)
{
  return PyList_Size(list);
}

extern char *get_list_item_string(PyObject *list, size_t idx)
{
  PyObject *pValue;
  pValue = PyList_GetItem(list, idx);

  char * rtn = PyString_AsString(pValue);
  Py_DECREF(pValue);
  return rtn;
}

extern PyObject *load_module(char *module_name)
{
  PyObject *pName, *pModule;

  pName = PyString_FromString(module_name);
  /* Error checking of pName left out */

  pModule = PyImport_Import(pName);
  Py_DECREF(pName);

  return pModule;
}

extern PyObject *create_actor_system(PyObject *pModule, PyObject *args)
{
  PyObject *pFunc, *pValue;

  pFunc = PyObject_GetAttrString(pModule, "create_actor_system");
  pValue = PyObject_CallFunctionObjArgs(pFunc, args, NULL);
  Py_DECREF(pFunc);

  return pValue;
}

extern PyObject *get_actor_count(PyObject *pModule)
{
  PyObject *pFunc, *pValue;
  pFunc = PyObject_GetAttrString(pModule, "get_actor_count");
  pValue = PyObject_CallFunctionObjArgs(pFunc, NULL);
  Py_DECREF(pFunc);
  return pValue;
}

extern char *get_app_name(PyObject *pModule)
{
  PyObject *pFunc, *pValue;
  pFunc = PyObject_GetAttrString(pModule, "get_app_name");
  pValue = PyObject_CallFunctionObjArgs(pFunc, NULL);
  char * rtn = PyString_AsString(pValue);
  Py_DECREF(pValue);
  return rtn;
}

extern char *get_name(PyObject *pObj)
{
  PyObject *pValue;
  pValue = PyObject_GetAttrString(pObj, "name");
  char * rtn = PyString_AsString(pValue);
  Py_DECREF(pValue);
  return rtn;
}

extern PyObject *get_attribute(PyObject *pObj, const char *attrName)
{
  PyObject *pValue;
  pValue = PyObject_GetAttrString(pObj, attrName);
  return pValue;
}

extern PyObject *get_none()
{
  return Py_None;
}

extern char *get_string_attribute(PyObject *pObj, const char *attrName)
{
  PyObject *pValue;
  pValue = PyObject_GetAttrString(pObj, attrName);
  char * rtn = PyString_AsString(pValue);
  Py_DECREF(pValue);
  return rtn;
}

uint64_t *split_uint_128(__uint128_t big)
{
  uint64_t *r = malloc(2 * sizeof(uint64_t));
  r[0] = (uint64_t) (big >> 64);
  r[1] = (uint64_t) (big - (((__uint128_t) r[0]) << 64));
  return r;
}

extern PyObject *call_fn_u128arg(PyObject *actor, const char* funcName, __uint128_t arg)
{
  PyObject *pFunc, *pValue, *pLeft, *pRight;

  uint64_t *longs = split_uint_128(arg);

  pLeft = PyLong_FromUnsignedLongLong(longs[0]);
  pRight = PyLong_FromUnsignedLongLong(longs[1]);
  pFunc = PyObject_GetAttrString(actor, funcName);
  pValue = PyObject_CallFunctionObjArgs(pFunc, pLeft, pRight, NULL);
  Py_DECREF(pLeft);
  Py_DECREF(pRight);
  Py_DECREF(pFunc);
  free(longs);

  return pValue;
}

extern PyObject *call_fn_noargs(PyObject *actor, const char* funcName)
{
  PyObject *pFunc, *pValue;

  pFunc = PyObject_GetAttrString(actor, funcName);
  pValue = PyObject_CallFunctionObjArgs(pFunc, NULL);
  Py_DECREF(pFunc);

  return pValue;
}

extern size_t call_fn_sizet_noargs(PyObject *actor, const char* funcName)
{
  PyObject *pFunc, *pValue;

  pFunc = PyObject_GetAttrString(actor, funcName);
  pValue = PyObject_CallFunctionObjArgs(pFunc, NULL);
  Py_DECREF(pFunc);

  size_t sz = PyInt_AsSsize_t(pValue);
  Py_DECREF(pValue);
  return sz;
}

extern size_t call_fn_sizet_bufferarg(PyObject *actor, const char* funcName, char *bytes, size_t size)
{
  PyObject *pFunc, *pValue, *pBytes;

  pFunc = PyObject_GetAttrString(actor, funcName);
  pBytes = PyBytes_FromStringAndSize(bytes, size);
  pValue = PyObject_CallFunctionObjArgs(pFunc, pBytes, NULL);

  size_t sz = PyInt_AsSsize_t(pValue);
  Py_DECREF(pFunc);
  Py_DECREF(pBytes);
  Py_DECREF(pValue);
  return sz;
}

extern PyObject *call_fn_bufferarg(PyObject *actor, const char* funcName, char *bytes, size_t size)
{
  PyObject *pFunc, *pValue, *pBytes;

  pFunc = PyObject_GetAttrString(actor, funcName);
  pBytes = PyBytes_FromStringAndSize(bytes, size);
  pValue = PyObject_CallFunctionObjArgs(pFunc, pBytes, NULL);

  Py_DECREF(pFunc);
  Py_DECREF(pBytes);
  return pValue;
}

extern char *call_str_fn_noargs(PyObject *pObj, const char *fName)
{
  PyObject *pFunc, *pValue;
  pFunc = PyObject_GetAttrString(pObj, fName);
  pValue = PyObject_CallFunctionObjArgs(pFunc, NULL);
  Py_DECREF(pFunc);
  char * rtn = PyString_AsString(pValue);
  Py_DECREF(pValue);
  return rtn;
}

extern char *call_str_fn(PyObject *pObj, const char *fName, PyObject *args)
{
  PyObject *pFunc, *pValue;
  pFunc = PyObject_GetAttrString(pObj, fName);
  pValue = PyObject_CallFunctionObjArgs(pFunc, args, NULL);
  Py_DECREF(pFunc);
  char * rtn = PyString_AsString(pValue);
  Py_DECREF(pValue);
  return rtn;
}

extern PyObject *call_fn(PyObject *actor, const char* funcName, PyObject *args)
{
  PyObject *pFunc, *pCallLog;

  pFunc = PyObject_GetAttrString(actor, funcName);
  pCallLog = PyObject_CallFunctionObjArgs(pFunc, args, NULL);
  Py_DECREF(pFunc);

  return pCallLog;
}

extern PyObject *call_fn_with_str(PyObject *actor,
                                  const char* funcName,
                                  const char* strArg,
                                  PyObject *args)
{
  PyObject *pFunc, *pCallLog, *pStrArg;

  pFunc = PyObject_GetAttrString(actor, funcName);
  pStrArg = PyString_FromString(strArg);
  pCallLog = PyObject_CallFunctionObjArgs(pFunc, pStrArg, args, NULL);
  Py_DECREF(pFunc);
  Py_DECREF(pStrArg);

  return pCallLog;
}

extern PyObject *call_fn_with_id(PyObject *actor, const char* funcName,
    __uint128_t sender_id, PyObject *args)
{
  PyObject *pFunc, *pCallLog, *pLeft, *pRight;
  uint64_t *longs = split_uint_128(sender_id);
  pLeft = PyLong_FromUnsignedLongLong(longs[0]);
  pRight = PyLong_FromUnsignedLongLong(longs[1]);
  pFunc = PyObject_GetAttrString(actor, funcName);
  pCallLog = PyObject_CallFunctionObjArgs(pFunc, pLeft, pRight, args, NULL);
  Py_DECREF(pFunc);
  Py_DECREF(pLeft);
  Py_DECREF(pRight);
  free(longs);

  return pCallLog;
}

extern __uint128_t join_longs(PyObject *long_pair)
{
  uint64_t l = PyLong_AsUnsignedLongLong(PyTuple_GetItem(long_pair, 0));
  uint64_t r = PyLong_AsUnsignedLongLong(PyTuple_GetItem(long_pair, 1));
  __uint128_t s = l;
  s = s << 64;
  s += r;
  return s;
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
    PyObject *wactor = PyObject_GetAttrString(module, "wactor");
    g_user_deserialization_fn = PyObject_GetAttrString(wactor, "deserialize");
    g_user_serialization_fn = PyObject_GetAttrString(wactor, "serialize");
    Py_DECREF(wactor);
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
    size_t size = PyString_Size(user_bytes);
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
    size_t size = PyString_Size(user_bytes);

    unsigned char *ubytes = (unsigned char *) bytes;

    ubytes[0] = (unsigned char)(size >> 24);
    ubytes[1] = (unsigned char)(size >> 16);
    ubytes[2] = (unsigned char)(size >> 8);
    ubytes[3] = (unsigned char)(size);

    memcpy(bytes + 4, PyString_AsString(user_bytes), size);

    Py_DECREF(user_bytes);
  }
}

