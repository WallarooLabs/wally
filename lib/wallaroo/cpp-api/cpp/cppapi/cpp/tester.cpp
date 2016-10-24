/**
 * Kevin A. Goldstein R. (kevin@sendence.com)
 *
 * FILE:   tester.cpp
 * DSCRPT: comment
 */


#include <WallarooCppApi/Buffers.hpp>
#include <WallarooCppApi/Logger.hpp>
#include <WallarooCppApi/WallarooVersion.hpp>

#include <getopt.h>
#include <iostream>





using namespace std;
using namespace spdlog;
using namespace wallaroo;


//------------------------------------------------
// show version numbers
void showVersion ()
{
  Logger::getLogger()->warn("Wallaroo CPP API, Version: {}.{}", Wallaroo_VERSION_MAJOR, Wallaroo_VERSION_MINOR);
}





//------------------------------------------------
// show this systems endianness, as defined by cmake
void testEndian ()
{
  string testname = "endianness";
  Logger::getLogger()->warn("Starting '{}' test", testname);
#ifdef _LITTLE_ENDIAN
  Logger::getLogger()->warn("LITTLE ENDIAN");
#elif _BIG_ENDIAN
  Logger::getLogger()->warn("BIG ENDIAN");
#endif
  Logger::getLogger()->warn("Ending '{}' test", testname);
}





//------------------------------------------------
// encode and decode a string...
void testStrings ()
{
  string testname = "string";
  Logger::getLogger()->warn("Starting '{}' test", testname);
  string in = "hello world";
  int len = in.length() + sizeof(short) + 1;
  ManagedBuffer pkt(len);
  pkt << in;

  RawBuffer pkt2(pkt.extractPointer(), len);
  string out;
  pkt2 >> out;
  cout << "out string:" << out << endl;
  Logger::getLogger()->warn("Ending '{}' test", testname);
}





//------------------------------------------------
// create two packets with base types, encode and
// decode and ensure they are the same
void testPackets ()
{
  string testname = "packets";
  Logger::getLogger()->warn("Starting '{}' test", testname);
  int sz =
      sizeof(int) * 4 + // 4 ints
      sizeof(bool) +
      sizeof(double);
  int invals[] = {42, 19, -42, 10009};
  ManagedBuffer* pkt1 = new ManagedBuffer(sz);
  *pkt1 << invals[0];
  *pkt1 << invals[1];
  *pkt1 << invals[2];
  *pkt1 << invals[3];
  *pkt1 << true;
  *pkt1 << 22.58;


  shared_ptr<logger> logger = Logger::getLogger();
  for (int i = 0; i < 4; i++)
  {
    logger->info("encoded:[{}]=[{}]", i, invals[i]);
  }


  char* ptr = pkt1->extractPointer();
  delete pkt1;
  Buffer* pkt2 = new RawBuffer(ptr, sz);
  int outvals[4];
  double outdouble;
  bool outbool;
  *pkt2 >> outvals[0];
  *pkt2 >> outvals[1];
  *pkt2 >> outvals[2];
  *pkt2 >> outvals[3];
  *pkt2 >> outbool;
  *pkt2 >> outdouble;
  for (int i = 0; i < 4; i++)
  {
    logger->info("decoded:[{}]=[{}]", i, outvals[i]);
  }
  logger->info("outbool=[{}]", outbool);
  logger->info("outdouble=[{}]", outdouble);
  delete pkt2;

  Logger::getLogger()->warn("Ending '{}' test", testname);
}




//------------------------------------------------
// test the packet externally allocated array
// capabilities
void testBinaryArray ()
{
  string testname = "binary (raw buffer)";
  Logger::getLogger()->warn("Starting '{}' test", testname);


  int arrsz = (sizeof(int) * 2) + (sizeof(double) * 2);
  ManagedBuffer mbuff(arrsz);
  int ic1 = 1, ic2 = 2;
  double dc1 = 1.0, dc2 = 22.5;
  mbuff << ic1;
  mbuff << dc1;
  mbuff << dc2;
  mbuff << ic2;

  int i1 = 0, i2 = 0;
  double d1 = 0.0, d2 = 0.0;
  RawBuffer rbuff(mbuff.extractPointer(), arrsz);
  rbuff >> i1;
  rbuff >> d1;
  rbuff >> d2;
  rbuff >> i2;

  if ((i1 == ic1) && (i2 == ic2) && (d1 == dc1) && (d2 == dc2))
  {
    Logger::getLogger()->info("Raw buffer unmarshalled all values correctly");

  }
  else
  {
    Logger::getLogger()->error("Raw buffer FAILED!, Values[{}={}, {}={}, {}={}, {}={}]",
                               ic1, i1,
                               dc1, d1,
                               dc2, d2,
                               ic2, i2);
  }

  Logger::getLogger()->warn("Ending '{}' test", testname);
  return;
}




//------------------------------------------------
// test overflow options on packet
void testOverflow ()
{
  string testname = "overflow";
  Logger::getLogger()->warn("Starting '{}' test", testname);
  shared_ptr<logger> logger = Logger::getLogger();
  logger->info("Encoding...");
  ManagedBuffer inpkt(sizeof(int));
  inpkt << 10;
  inpkt << 20;
  inpkt << 30;


  int sz1 = 0, sz2 = 0, sz3 = 0;
  logger->info("Decoding...");
  RawBuffer outpkt(inpkt.extractPointer(), sizeof(int));
  outpkt >> sz1;
  outpkt >> sz2;
  outpkt >> sz3;

  logger->info("sz1:{}", sz1);
  logger->info("sz2:{}", sz2);
  logger->info("sz3:{}", sz3);
  Logger::getLogger()->warn("Ending '{}' test", testname);
}





//------------------------------------------------
// test comparing to basic objects
void testCompare ()
{
  string testname = "class comparison";
  Logger::getLogger()->warn("Starting '{}' test", testname);
  Logger::getLogger()->warn("Ending '{}' test", testname);
}





void printHelp (const char* progname_)
{
  cout << "test the serialization/deserialization functionality used in Wallaroo" << endl;
  cout << "\t" << progname_ << " [-h] [-a] [-e] [-o] [-s] [-p] [-c] [-b] [-p] [-l]" << endl;
  cout << "\t-h: print help/usage message" << endl;
  cout << "\t-a: perform all tests" << endl;
  cout << "\t-e: only execute endianness test" << endl;
  cout << "\t-o: only execute overflow test" << endl;
  cout << "\t-p: only execute packet test" << endl;
  cout << "\t-s: only execute string test" << endl;
  cout << "\t-b: only execute binary (raw buffer) test" << endl;
}





//------------------------------------------------
int main (int argc_, char** argv_)
{
  bool all = false;
  char c;
  while ((c = getopt(argc_, argv_, "haeospbm")) != -1)
  {
    switch (c)
    {
      case 'h':
        printHelp(argv_[0]);
        return 0;
      case 'a':
        all = true;
        break;
      case 'e':
        showVersion();
        testEndian();
        return 0;
      case 'o':
        showVersion();
        testOverflow();
        return 0;
      case 's':
        showVersion();
        testStrings();
        return 0;
      case 'p':
        showVersion();
        testPackets();
        return 0;
      case 'b':
        showVersion();
        testBinaryArray();
        return 0;
      case 'm':
        showVersion();
        testCompare();
        return 0;
      default:
        printHelp(argv_[0]);
        return EXIT_FAILURE;
    }
  }

  //
  // done some tests
  //

  if (all)
  {
    showVersion();
    testEndian();
    testOverflow();
    testStrings();
    testPackets();
    testBinaryArray();
    testCompare();
  }
  else
  {
    printHelp(argv_[0]);
    return EXIT_FAILURE;
  }


  //
  // done
  //
  return EXIT_SUCCESS;
}

