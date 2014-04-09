#include "arguments.hpp"
#include "builtin/module.hpp"
#include "builtin/class.hpp"
#include "builtin/symbol.hpp"
#include "builtin/executable.hpp"
#include "builtin/exception.hpp"
#include "dispatch.hpp"
#include "global_cache.hpp"
#include "lookup_data.hpp"

#include <sstream>

namespace rubinius {
  Object* Dispatch::send(STATE, CallFrame* call_frame, Arguments& args,
                         MethodMissingReason reason)
  {
    // std::cout << "[vm/Dispatch#send-no-args] received method " << args.recv()->to_string(state, false) << "\n";
    LookupData lookup(args.recv(), args.recv()->lookup_begin(state), G(sym_protected));

    return send(state, call_frame, lookup, args, reason);
  }

  Object* Dispatch::send(STATE, CallFrame* call_frame, LookupData& lookup,
                         Arguments& args, MethodMissingReason reason)
  {
    Symbol* original_name = name;
    // std::cout << "[vm/Dispatch#send] received method " << original_name->cpp_str(state) << " on object " << args.recv()->to_string(state, false) <<" \n";

    if(!resolve(state, name, lookup)) {
      state->vm()->set_method_missing_reason(reason);

      method_missing = reason;
      lookup.min_visibility = G(sym_private);
      if(!resolve(state, G(sym_method_missing), lookup)) {
        std::ostringstream msg;
        msg << "no method_missing for ";
        msg << lookup.from->to_string(state);
        msg << "#" << original_name->to_string(state);

        Exception::internal_error(state, call_frame, msg.str().c_str());
        return 0;
      }

      method_missing = reason;
    }

    if(method_missing) {
      args.unshift(state, original_name);
    }

    return method->execute(state, call_frame, method, module, args);
  }

  bool Dispatch::resolve(STATE, Symbol* name, LookupData& lookup) {
    // std::cout << "[vm/Dispatch#resolve] received symbol " << name->cpp_str(state) << "\n";
    return GlobalCache::resolve(state, name, *this, lookup);
  }
}
