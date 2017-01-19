//
// Created by Kevin A. Goldstein R.  on 9/26/16.
//

#ifndef __CPPAPI_LOGGER_HPP__
#define __CPPAPI_LOGGER_HPP__





#include <spdlog/spdlog.h>
#include <memory>





namespace wallaroo
{





class Logger
{
private:
    static Logger* _instance;
    std::shared_ptr<spdlog::logger> _logger;
    Logger ();

public:
    virtual ~Logger ();

public:
    static std::shared_ptr<spdlog::logger> getLogger ();
    static Logger* getInstnace ();
};

}

#endif //__CPPAPI_LOGGER_HPP__
