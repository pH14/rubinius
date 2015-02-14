#ifndef RBX_DISPATCH_HPP
#define RBX_DISPATCH_HPP

#include "vm.hpp"
#include "compiled_code.hpp"

namespace rubinius {
  class Symbol;
  class Module;
  class Object;
  class Executable;
  struct CallFrame;
  class Arguments;
  struct LookupData;

  class Dispatch {
  public:
    Symbol* name;
    Module* module;
    Executable* method;
    Symbol* visibility;
    MethodMissingReason method_missing;

    Dispatch(Symbol* name)
      : name(name)
      , module(0)
      , method(0)
      , visibility(0)
      , method_missing(eNone)
    {}

    Object* send(STATE, CallFrame* call_frame, Arguments& args,
                 MethodMissingReason reason = eNormal);
    Object* send(STATE, CallFrame* call_frame, LookupData& lookup, Arguments& args,
                 MethodMissingReason reason = eNormal);
    bool resolve(STATE, Symbol* name, LookupData& lookup);
    std::string symbol_translate(STATE, const std::string& meth_name);
  private:
    Arguments arguments_from_proxy_method(STATE, Arguments& args, Object* proxy_method_return_args, Object* recv, Object* before_method_args);
    void arguments_from_call(STATE, Object* returned_args, Arguments& original_args, Arguments& updated_args, CompiledCode* compiled_code);
  };
}

#endif
