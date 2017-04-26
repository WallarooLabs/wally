#include <stdio.h>

#ifdef __APPLE__
    #include <Python/Python.h>
#else
    #include <python2.7/Python.h>
#endif

extern void initialize_python()
{
  Py_Initialize();
}

extern void test()
{
  printf("hello c\n");
}

extern void test_python()
{
  PyRun_SimpleString("from time import time,ctime\n"
                     "print 'Today is',ctime(time())\n");
}

extern PyObject* get_python_module(char *module_name)
{
  PyObject *pName, *pModule;

  pName = PyString_FromString(module_name);
  /* Error checking of pName left out */

  pModule = PyImport_Import(pName);
  Py_DECREF(pName);
  return pModule;
}

extern PyObject *call_python_function(PyObject *pModule, char *function_name)
{
  PyObject *pArgs, *pFunc, *pValue;

  pFunc = PyObject_GetAttrString(pModule, function_name);
  pArgs = PyTuple_New(0);
  pValue = PyObject_CallObject(pFunc, pArgs);
  Py_DECREF(pFunc);
  return pValue;
}

extern PyObject *call_python_function_with_arg(PyObject *pModule, char *function_name, PyObject *arg)
{
  PyObject *pArgs, *pFunc, *pValue;

  pFunc = PyObject_GetAttrString(pModule, function_name);
  pArgs = PyTuple_New(1);
  PyTuple_SetItem(pArgs, 0, arg);
  pValue = PyObject_CallObject(pFunc, pArgs);
  Py_DECREF(pFunc);
  return pValue;
}

extern size_t get_item_count(PyObject *pList)
{
  return PyList_Size(pList);
}

extern char* get_action_at(PyObject *pList, size_t idx)
{
  PyObject *action_and_thing = PyList_GetItem(pList, idx);
  PyObject *action = PyTuple_GetItem(action_and_thing, 0);
  return PyString_AsString(action);
}
