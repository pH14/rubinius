#include "arguments.hpp"
#include "builtin/module.hpp"
#include "builtin/class.hpp"
#include "builtin/symbol.hpp"
#include "builtin/executable.hpp"
#include "builtin/exception.hpp"
#include "dispatch.hpp"
#include "global_cache.hpp"
#include "lookup_data.hpp"

#include "builtin/object.hpp"
#include "machine_code.hpp"
#include "object_utils.hpp"
#include "call_frame.hpp"
#include "exception.hpp"
#include "compiled_code.hpp"

#include <sstream>

namespace rubinius {

      std::string Dispatch::symbol_translate(STATE, const std::string& meth_name) {
        if (meth_name == "*") {
            return "op__multiply";
        }
        else if (meth_name == "+") {
            return "op__plus";
        }
        else if (meth_name == "[]") {
            return "op__index";
        }
        else if (meth_name == "%") {
            return "op__modulo";
        }
        else if (meth_name == "<<") {
            return "op__concat";
        }
        else {
            return meth_name;
        }
      }

  Arguments Dispatch::arguments_from_proxy_method(STATE, Arguments& args, Object* proxy_method_return_args, Object* recv) {
    // if (Array* each_hooked_arg = try_as<Array>(proxy_method_return_args)) {
    //   std::cerr << "[vm/CallSite#execute] Call site's args were an array " << each_hooked_arg << "\n";

    //   Array* caller_array = Array::create(state, 1);
    //   caller_array->append(state, recv);

    //   Arguments arguments(args.name(), each_hooked_arg);
    //   arguments.set_recv(args.recv());
    //   arguments.prepend(state, caller_array);

    //   return arguments;
    // } else {
      std::cerr << "[vm/CallSite#execute] Call site's args were just one arg " << proxy_method_return_args->to_string(state, true) << "\n";

      Tuple* args_tuple = Tuple::from(state, 2, recv, proxy_method_return_args);

      Arguments arguments(args.name());
      arguments.set_recv(args.recv());
      arguments.use_tuple(args_tuple, 2);
      return arguments;
    // }
  }

  void Dispatch::arguments_from_call(STATE, Object* returned_args, Arguments& original_args, Arguments& updated_args, CompiledCode* compiled_code) {
      if(!returned_args) {
        std::cerr << "[vm/CallSite#execute] Secure context didn't return anything for " << original_args.name()->cpp_str(state) << " .\n";
        updated_args = original_args;
        return;
      }

      // for(size_t i = 0; i < original_args.as_array(state)->size(); i++) {
      //   std::cerr << "[vm/CallSite#execute] Arg << " << i << " is " << original_args.as_array(state)->get(state, i)->to_string(state) << "\n";
      // }
      
      if(Array* each_hooked_arg = try_as<Array>(returned_args)) {
        std::cerr << each_hooked_arg->get(state, 0)->direct_class(state);
        std::cerr << "[vm/CallSite#execute] Number of hooked args is: " << each_hooked_arg->size() << "\n";

        size_t args_range = each_hooked_arg->size();
        Array* ary = Array::create(state, args_range);

        size_t returned_args_index = 0;
        for(size_t i = 0; i < args_range; i++) {
          std::cerr << "[vm/CallSite#execute] Hooked arg is " << each_hooked_arg->get(state,i)->to_string(state) << "\n";

          Object* returned_arg = each_hooked_arg->get(state, i);

          if (returned_arg->is_hooked_block_p()) {
            updated_args.set_block(each_hooked_arg->get(state, each_hooked_arg->size() - 1));
          } else {
            ary->set(state, returned_args_index++, each_hooked_arg->get(state, i));
          }
        }

        updated_args.use_array(ary);

      } else { // if try_as fails, only have one argument

        std::cerr << "[vm/CallSite#execute] Dreaded ambiguous case. Object is : " << returned_args->to_string(state, false) << "\n";

        // Potentially ambiguity of this case is largely resolved by the hooked_block?
        // attribute stored in the header object. If it's a hooked block, we try that
        // since the developer definitely meant for that to be passed. Otherwise, if
        // the wrapped method requires an argument, we give it whatever is returned
        // in an attempt to do the right thing. It's still possible that the value was
        // not meant to be returned (implicit return) and the wrapped method is getting
        // something it wasn't expecting, but at that point, I think that's more of a
        // flaw in the pre-hook than here in the VM.

        // system.cpp lookup code

        std::cerr << "[vm/CallSite#execute] Call site has total args: " << compiled_code->total_args()->to_native() << " and " << compiled_code->required_args()->to_native() << "\n";

        native_int threshold = 1;
        if (returned_args->is_hooked_block_p()) {
          std::cerr << "[vm/CallSite#execute] -- is a block so trying that...\n";
          updated_args.set_block(returned_args);
        } else if (compiled_code->total_args()->to_native() >= threshold) {
          std::cerr << "[vm/CallSite#execute] -- requires an arg so trying that...\n";

          Tuple* args_tuple = Tuple::from(state, 1, returned_args);
          // updated_args.use_argument(returned_args);
          updated_args.use_tuple(args_tuple, 1);
        }
      }
  }

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


      std::string context_method_name = symbol_translate(state, name->cpp_str(state));

      if(args.recv()->is_secure_context_p() && !(context_method_name == "secure_context" || context_method_name == "secure_context?" || context_method_name == "secure_context=")) {

        Object* const recv = args.recv();
        CallFrame* const orig_call_frame = call_frame;

        std::cerr << "----------------------------\n";
        std::cerr << "[vm/CallSite#execute] Receiver " << recv->to_string(state, true) << " has a secure context for f'n: " << args.name()->cpp_str(state) << "\n";
        std::cerr << "[vm/CallSite#execute] Arg f'n: " << args.name()->cpp_str(state) << " CS f'n: " << this->name->cpp_str(state) << "\n";
        std::cerr << "[vm/CallSite#execute] Number of args : " << args.total() << "\n";
        std::cerr << "[vm/CallSite#execute] Original CallSite symbol name is: " << this->name->cpp_str(state) << "\n";







        CompiledCode* compiledCode = try_as<CompiledCode>(this->method);

        Object* secure_context_object = recv->get_secure_context_prim(state);

        std::cerr << "[vm/CallSite#execute] lookup thingy : " << symbol_translate(state, args.name()->cpp_str(state)) << "\n";


        Symbol* before_symbol = state->shared().symbols.lookup(state, "before_" + context_method_name);
        Symbol* after_symbol  = state->shared().symbols.lookup(state, "after_" + context_method_name);

        Arguments before_updated_args(args.name());

        std::cerr << "[vm/CallSite#execute] Before sym " << before_symbol->cpp_str(state) << "\n";
        std::cerr << "[vm/CallSite#execute] After sym " << after_symbol->cpp_str(state) << "\n";

        for(size_t i = 0; i < args.as_array(state)->size(); i++) {
          std::cerr << "[vm/CallSite#execute] Before pre-hook, Arg << " << i << " is " << args.as_array(state)->get(state, i)->to_string(state) << "\n";
        }

        if (CBOOL(secure_context_object->respond_to(state, before_symbol, cTrue))) {
          std::cerr << "[vm/CallSite#execute] Context does have pre-hook for call site\n";
          std::cerr << "[vm/CallSite#execute] Block given is " << args.block()->to_string(state, true) << "\n";

          // All hooks should have a reference to the caller
          Array* caller_array = Array::create(state, 1);
          caller_array->append(state, recv);
          args.prepend(state, caller_array);

          // Execute pre-hook with modified args
          Object* returned_args = secure_context_object->send(state, call_frame, before_symbol, args.as_array(state), args.block(), true);

          LookupData lookup(orig_call_frame->self(), recv->lookup_begin(state), G(sym_private));
          Dispatch dis(this->name);

          if(!dis.resolve(state, this->name, lookup)) {
            std::cerr << "[vm/CallSite#execute] Could not resolve method before call to executor\n";
          }

          compiledCode = try_as<CompiledCode>(this->method);

          std::cerr << "[vm/CallSite#execute] Discovered method has total args: " << compiledCode->total_args()->to_native() << " and " << compiledCode->required_args()->to_native() << " and arity " << compiledCode->arity()->to_uint() << "\n";

          this->arguments_from_call(state, returned_args, args, before_updated_args, compiledCode);

          std::cerr << "[vm/CallSite#execute] Setting receiver...\n";

          before_updated_args.set_recv(recv);

          for(size_t i = 0; i < before_updated_args.as_array(state)->size(); i++) {
            std::cerr << "[vm/CallSite#execute] Before original method, with pre-hooked args << " << i << " is " << before_updated_args.as_array(state)->get(state, i)->to_string(state) << "\n";
          }

        } else {
          std::cerr << "[vm/CallSite#execute] Context does _not_ have pre-hook for call site\n";
          before_updated_args = args;
        }







        std::cerr << "[vm/CallSite#execute] Now calling original CallSite: " << this->name->cpp_str(state) << "\n";

        Object* proxy_method_return_args = method->execute(state, call_frame, method, module, before_updated_args);
        std::cerr << "[vm/CallSite#execute] After original call, returns object " << proxy_method_return_args->to_string(state, true) << "\n";







        if (CBOOL(secure_context_object->respond_to(state, after_symbol, cTrue))) {
          std::cerr << "[vm/CallSite#execute] Context does have post-hook for call site " << this->name->cpp_str(state) << "\n";

          if (! proxy_method_return_args) {
            std::cerr << "[vm/CallSite#execute] No returned values from original methods\n";
            return secure_context_object->send(state, call_frame, after_symbol, true);
          }

          Arguments after_updated_args = arguments_from_proxy_method(state, args, proxy_method_return_args, recv);

          return secure_context_object->send(state, call_frame, after_symbol, after_updated_args.as_array(state), after_updated_args.block(), true);
        } else {
          std::cerr << "[vm/CallSite#execute] Context does _not_ have post-hook for call site! " << this->name->cpp_str(state) << "\n";
          return proxy_method_return_args;
        }
      }

    return method->execute(state, call_frame, method, module, args);
  }

  bool Dispatch::resolve(STATE, Symbol* name, LookupData& lookup) {
    // std::cout << "[vm/Dispatch#resolve] received symbol " << name->cpp_str(state) << "\n";
    return GlobalCache::resolve(state, name, *this, lookup);
  }
}
