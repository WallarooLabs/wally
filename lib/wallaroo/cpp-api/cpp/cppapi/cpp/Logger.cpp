//
// Created by Kevin A. Goldstein R.  on 9/26/16.
//

#include "Logger.hpp"
#include <exception>
#include <iostream>
#include <string>
#include <cstdlib>

using std::exception;
using std::string;




namespace wallaroo
{

Logger* Logger::_instance = nullptr;





//------------------------------------------------

Logger::Logger()
{
#if defined(CONSOLE)
  try
  {
    _logger = spdlog::stdout_color_mt("console");
  }
  catch(std::exception& e_)
  {
    _logger = spdlog::get("console");
  }
#else
  int q_size = 8192;
  spdlog::set_async_mode(q_size, spdlog::async_overflow_policy::block_retry,
      nullptr,
      std::chrono::seconds(2));

  string path;
  const char* strPath = std::getenv("WALLAROO_LOGPATH");
  if (strPath == nullptr )
  {
    path = "/tmp";
    std::cerr << "WALLAROO_LOGPATH NOT SET! Defaulting to:" << path << std::endl;
  }
  else
  {
    path = strPath;
  }


  //
  //
  //
  string fqn = path + "/wallaroo.log";
  std::cout << "wallaroo log:" << fqn << std::endl;
  _logger = spdlog::basic_logger_mt("basic_logger", fqn.c_str());
#endif
  _logger->set_level(spdlog::level::info);
}




//------------------------------------------------
Logger::~Logger()
{
  //delete _logger;
}




//------------------------------------------------
// yeah - this should be trhead safe but... eh...
Logger* Logger::getInstnace()
{
  if (nullptr == _instance)
  {
    _instance = new Logger();
  }

  return _instance;
}




//------------------------------------------------
std::shared_ptr<spdlog::logger> Logger::getLogger()
{
  return getInstnace()->_logger;
}


}
