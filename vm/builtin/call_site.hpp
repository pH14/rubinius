#ifndef RBX_BUILTIN_CALL_SITE_HPP
#define RBX_BUILTIN_CALL_SITE_HPP

#include "builtin/object.hpp"
#include "builtin/symbol.hpp"
#include "machine_code.hpp"
#include "object_utils.hpp"
#include "arguments.hpp"
// #include "method_table.hpp"
#include "call_frame.hpp"
#include "exception.hpp"

namespace rubinius {

  class Dispatch;
  class Arguments;
  class Symbol;

  typedef Object* (CacheExecuteFunc)(STATE, CallSite*, CallFrame*, Arguments&);
  typedef Object* (FallbackExecuteFunc)(STATE, CallSite*, CallFrame*, Arguments&);
  typedef void (CacheUpdateFunc)(STATE, CallSite*, Class*, Dispatch&);

  typedef CacheExecuteFunc* CacheExecutor;
  typedef FallbackExecuteFunc* FallbackExecutor;
  typedef CacheUpdateFunc* CacheUpdater;

  class CallSiteInformation {
  public:
    CallSiteInformation(Executable* e, int i)
      : executable(e)
      , ip(i)
    {}

    Executable* executable;
    int ip;
  };

  class CallSite : public Object {
  public:
    const static object_type type = CallSiteType;

    Symbol* name_; // slot
    CacheExecutor    executor_;
    FallbackExecutor fallback_;
    CacheUpdater     updater_;

    Executable* executable_; // slot
    int ip_;

  public:
    attr_accessor(name, Symbol);
    attr_accessor(executable, Executable);

    static void init(STATE);

    int ip() const {
      return ip_;
    }

    // Rubinius.primitive+ :call_site_ip
    Integer* ip_prim(STATE);

    static CallSite* empty(STATE, Symbol* name, Executable* executable, int ip);

    static CacheExecuteFunc empty_cache;
    static CacheExecuteFunc empty_cache_private;
    static CacheExecuteFunc empty_cache_vcall;
    static CacheExecuteFunc empty_cache_super;
    static CacheExecuteFunc empty_cache_custom;

    static CacheUpdateFunc empty_cache_updater;

    bool regular_call() const {
      return type_id() == MonoInlineCacheType || type_id() == PolyInlineCacheType;
    }

    bool update_and_validate(STATE, CallFrame* call_frame, Object* recv, Symbol* vis, int serial);

    void set_is_private() {
      executor_ = empty_cache_private;
      fallback_ = empty_cache_private;
    }

    void set_is_super() {
      executor_ = empty_cache_super;
      fallback_ = empty_cache_super;
    }

    void set_is_vcall() {
      executor_ = empty_cache_vcall;
      fallback_ = empty_cache_vcall;
    }

    void set_call_custom() {
      executor_ = empty_cache_custom;
      fallback_ = empty_cache_custom;
    }

    void set_executor(CacheExecutor exec) {
      executor_ = exec;
      fallback_ = exec;
    }

    void update_call_site(STATE, CallSite* other) {
      if(this != other) {
        if(CompiledCode* ccode = try_as<CompiledCode>(executable_)) {
          ccode->machine_code()->store_call_site(state, ccode, ip_, other);
        }
      }
    }

    static bool lookup_method_missing(STATE, CallFrame* call_frame, Arguments& args, Dispatch& dis, Object* self, Module* begin);

    Object* execute(STATE, CallFrame* call_frame, Arguments& args) {
      Object* const recv = args.recv();
      CallFrame* const orig_call_frame = call_frame;
      // Arguments& const original_args = args;

      if(recv->is_secure_context_p()) {// && ((args.total() > 0) || args.block() != cNil)) {

        // Symbol* method_symbol = state->symbol("intercept_arguments");
        // CallSite* intercept_call_site = reinterpret_cast<CallSite*>(method_symbol);
        // std::cerr << "[vm/CallSite#execute] New CallSite symbol name is: " << intercept_call_site->name_->cpp_str(state) << "\n";

        std::cerr << "[vm/CallSite#execute] Receiver has a secure context for f'n: " << args.name()->cpp_str(state) << "\n";
        std::cerr << "[vm/CallSite#execute] Arg f'n: " << args.name()->cpp_str(state) << " CS f'n: " << this->name_->cpp_str(state) << "\n";
        std::cerr << "[vm/CallSite#execute] Number of args before call is: " << args.total() << "\n";
        std::cerr << "[vm/CallSite#execute] Original CallSite symbol name is: " << this->name_->cpp_str(state) << "\n";

        call_frame->dump();

        // Tuple* call_site_tuple = (Tuple*) MachineCode::call_sites(STATE);

        // for (native_int q = 0; q < call_site_tuple.num_fields(); q++) {
        //   Tuple t = call_site_tuple.at(q);
        // }

        // args.set_recv(recv->get_secure_context_prim(state));

        Object* secure_context_object = recv->get_secure_context_prim(state);

        Symbol* before_symbol = state->shared().symbols.lookup(state, "before_" + args.name()->cpp_str(state));
        // Symbol* after_symbol = state->shared().symbols.lookup(state, "after_" + args.name()->cpp_str(state));

        Arguments before_updated_args(args.name());
        Arguments after_updated_args(args.name());

        std::cerr << "[vm/CallSite#execute] Before sym " << before_symbol->cpp_str(state) << "\n";

          for(size_t i = 0; i < args.as_array(state)->size(); i++) {
            std::cerr << "[vm/CallSite#execute] Before pre-hook, Arg << " << i << " is " << args.as_array(state)->get(state, i)->to_string(state) << "\n";
          }

        Object* returned_args = secure_context_object->send(state, call_frame, before_symbol, args.as_array(state), args.block(), false);

        this->arguments_from_call(state, returned_args, args, before_updated_args);
        //  Symbol* SymbolTable::lookup(STATE, const std::string& str) {
        //       Object* send(STATE, CallFrame* caller, Symbol* name, Array* args,
        // Object* block = cNil, bool allow_private = true);
        // Object* Object::send(STATE, CallFrame* caller, Symbol* name, bool allow_private) {

        // Object* returned_args = (*executor_)(state, this, call_frame, args);
        // Object* returned_args = (*executor_)(state, this, call_frame, args);

          before_updated_args.set_recv(recv);

          std::cerr << "[vm/CallSite#execute] Now calling original CallSite: " << this->name_->cpp_str(state) << "\n";

          orig_call_frame->dump();
          return (*executor_)(state, this, orig_call_frame, before_updated_args);
          // Object* hooked_return = (*executor_)(state, this, orig_call_frame, args);

          // before_updated_args.use_array(try_as<Array>(hooked_return));

          // return secure_context_object->send(state, call_frame, after_symbol, args.as_array(state), args.block(), false);
      }

      return (*executor_)(state, this, call_frame, args);
    }


    void arguments_from_call(STATE, Object* returned_args, Arguments& original_args, Arguments& updated_args) {
        if(!returned_args) {
          std::cerr << "[vm/CallSite#execute] Secure context didn't return anything for " << original_args.name()->cpp_str(state) << " .\n";
          updated_args = original_args;
          // If the secure context doesn't return anything, args will be prepended with the symbol of the method call
          // Case when the pre-hook method does not exist and method_missing is not defined.
          // Treat it as though this call never happened.

          // std::cerr << "[vm/CallSite#execute] Number of args is: " << original_args.total() << "\n";

          // for(size_t i = 0; i < original_args.as_array(state)->size(); i++) {
          //   std::cerr << "[vm/CallSite#execute] Arg << " << i << " is " << original_args.as_array(state)->get(state, i)->to_string(state) << "\n";
          // }

          // so we remove that and call the function on the original receiver
          // if(args.total() > 0) {
          //   args.shift(state);
          // }
          // args.set_recv(recv);
        } else {
          bool block_given = (original_args.block() != cNil);
          std::cerr << "[vm/CallSite#execute] Block_given? " << block_given << "\n";

          if(original_args.total() > 0) {
            for(size_t i = 0; i < original_args.as_array(state)->size(); i++) {
              std::cerr << "[vm/CallSite#execute] Arg << " << i << " is " << original_args.as_array(state)->get(state, i)->to_string(state) << "\n";
            }
            
  // inline Class* Object::direct_class(STATE) const {
            if(Array* each_hooked_arg = try_as<Array>(returned_args)) {
              // TypeInfo* type_info = each_hooked_arg->get(state, 0)->type_info(state);
              // std::cerr << "[vm/CallSite#execute] Type info: ";
              // type_info->show_simple(state, each_hooked_arg->get(state, 0), 2);
              // std::cerr << "\n";

              std::cerr << each_hooked_arg->get(state, 0)->direct_class(state);

              std::cerr << "[vm/CallSite#execute] Number of hooked args is: " << each_hooked_arg->size() << "\n";

              size_t args_range = each_hooked_arg->size();
              std::cerr << "[vm/CallSite#execute] Args size before block subtraction is " << args_range << "\n";

              // The secure context returns (arg, arg, arg, .. block) if it's supposed to return a block
              if (block_given) {
                args_range--;
              }

              std::cerr << "[vm/CallSite#execute] Trying to make an array with size " << args_range << "\n";
              Array* ary = Array::create(state, args_range);

              std::cerr << "[vm/CallSite#execute] Will be adding in: " << args_range << " arguments\n";

              for(size_t i = 0; i < args_range; i++) {
                std::cerr << "[vm/CallSite#execute] Hooked arg is " << each_hooked_arg->get(state,i)->to_string(state) << "\n";
                ary->set(state, i, each_hooked_arg->get(state, i));
              }

              updated_args.use_array(ary);

              if (block_given) {
                std::cerr << "[vm/CallSite#execute] Original args does have block. Setting it on new args.\n";
                updated_args.set_block(each_hooked_arg->get(state, each_hooked_arg->size() - 1));
              }
            } else { // if try_as fails

              // Only 1 arg returned, original receiver takes 0 args, this means it should be a block
              if(block_given) {
                std::cerr << "[vm/CallSite#execute] Original args does have block, attaching. No args.\n";
                std::cerr << "[vm/CallSite#execute] -- " << original_args.total() << "\n";
                updated_args.set_block(returned_args);
              } else {
                Exception::argument_error(state, "secure context returned too few arguments");
              }
            }
          } else {
            if (block_given) {
              std::cerr << "[vm/CallSite#execute] Original args does have block, but no other args.\n";
              updated_args.set_block(returned_args);
            } else {
              /* This is an ambiguous case and should probably be solved after more thought from the API-aspect.
               * This is when the original method takes no arguments, but arguments (possibly a block) were returned 
               * by the secure context.
               * 
               * Since the last evaluated line in a method in Ruby often returns a value, the value returned by 
               * the secure context could be completely unintentional. In that case, we certainly don't want
               * to do anything with it. However, it's also possible that the secure context was supposed
               * to give a block to the method, but that will look the same here: 1 argument was returned.
               * There needs to be a way to distinguish these two cases, and checking if it's a Proc or lambda
               * here isn't sufficient.
               *
               */
              // Exception::argument_error(state, "secure context returned arguments to arity-0 method");
               // updated_args.use_argument()
            }
          }
        }
    }

    Object* fallback(STATE, CallFrame* call_frame, Arguments& args) {
      return (*fallback_)(state, this, call_frame, args);
    }

    void update(STATE, Class* klass, Dispatch& dispatch) {
      (*updater_)(state, this, klass, dispatch);
    }

    class Info : public TypeInfo {
    public:
      Info(object_type type)
        : TypeInfo(type)
      {
        allow_user_allocate = false;
      }

      virtual void mark(Object* obj, ObjectMark& mark);
      virtual void auto_mark(Object* obj, ObjectMark& mark);
      virtual void set_field(STATE, Object* target, size_t index, Object* val);
      virtual Object* get_field(STATE, Object* target, size_t index);
      virtual void populate_slot_locations();
    };
  };

}

#endif

