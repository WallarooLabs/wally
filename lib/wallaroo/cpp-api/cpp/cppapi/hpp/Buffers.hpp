//
// Created by Kevin A. Goldstein R.  on 9/29/16.
//

#ifndef __CPPAPI_BUFFERS_HPP__
#define __CPPAPI_BUFFERS_HPP__





#include <string>





using std::string;

namespace wallaroo
{





//--------------------------------------------------------------------
//
//--------------------------------------------------------------------
class Buffer
{
protected:
    int _bodySize;
    char* _body;
    char* _read;
    char* _write;

protected:
    bool writeData (const void* data_, const int size_, const bool networkOrder_ = true);
    bool readData (void* data_, const int size_, const bool networkOrder_ = true);
    void setBody (const int size_ = 0);

protected:
    Buffer ();
    Buffer (char* body_, int bodySz_);

public:
    virtual ~Buffer () = 0;


public:
    virtual Buffer& operator<< (const bool param_);
    virtual Buffer& operator<< (const char param_);
    virtual Buffer& operator<< (const unsigned short param_);
    virtual Buffer& operator<< (const short param_);
    virtual Buffer& operator<< (const unsigned int param_);
    virtual Buffer& operator<< (const int param_);
    virtual Buffer& operator<< (const double param_);
    virtual Buffer& operator<< (const string& str_);

    virtual Buffer& operator>> (bool& param_);
    virtual Buffer& operator>> (char& param_);
    virtual Buffer& operator>> (unsigned short& param_);
    virtual Buffer& operator>> (short& param_);
    virtual Buffer& operator>> (unsigned int& param_);
    virtual Buffer& operator>> (int& param_);
    virtual Buffer& operator>> (double& param_);
    virtual Buffer& operator>> (string& param_);
};




//--------------------------------------------------------------------
//
//--------------------------------------------------------------------
class ManagedBuffer : public Buffer
{
public:
    ManagedBuffer (int sz_);
    ManagedBuffer (const ManagedBuffer& buff_);
    virtual ~ManagedBuffer ();

public:
    char* extractPointer ()
    {
      char* holder = _body;
      _body = NULL;
      _read = NULL;
      _write = NULL;
      _bodySize = 0;
      return holder;
    }

};





//--------------------------------------------------------------------
//
//--------------------------------------------------------------------
class RawBuffer : public Buffer
{
public:
    RawBuffer (char* str_, int sz_);
    RawBuffer (const RawBuffer& rhs_);
    virtual ~RawBuffer ();
};
}


#endif //__CPPAPI_BUFFERS_HPP__
