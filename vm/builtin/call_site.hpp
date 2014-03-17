#ifndef RBX_BUILTIN_CALL_SITE_HPP
#define RBX_BUILTIN_CALL_SITE_HPP

#include "builtin/object.hpp"
#include "builtin/symbol.hpp"
#include "machine_code.hpp"
#include "object_utils.hpp"
#include "arguments.hpp"

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

      if(recv->is_secure_context_p() && args.total() > 0) {
        std::cerr << "[vm/CallSite#execute] Receiver has a secure context for f'n: " << args.name()->cpp_str(state) << "\n";
        std::cerr << "[vm/CallSite#execute] Number of args before call is: " << args.total() << "\n";

        args.set_recv(recv->get_secure_context_prim(state));

        Object* hooked_args = (*executor_)(state, this, call_frame, args);

        if(!hooked_args) {
          std::cerr << "[vm/CallSite#execute] Secure context didn't return anything.\n";
          std::cerr << "[vm/CallSite#execute] Number of args is: " << args.total() << "\n";

          for(size_t i = 0; i < args.as_array(state)->size(); i++) {
            std::cerr << "[vm/CallSite#execute] Arg << " << i << " is " << args.as_array(state)->get(state, i)->to_string(state) << "\n";
          }

          // If the secure context doesn't return anything, args will be prepended with the symbol of the method call
          // so we remove that and call the function on the original receiver
          args.shift(state);
          args.set_recv(recv);
        } else {
          Object* const original_recv = recv;
          Array* ary = Array::create(state, args.total());
          Array* each_hooked_arg = try_as<Array>(hooked_args);

          std::cerr << "[vm/CallSite#execute] Number of hooked args is: " << each_hooked_arg->size() << "\n";

          size_t args_range = each_hooked_arg->size();
          bool block_given = args.block() != NULL;

          if (!block_given) {
            args_range -= 1;
          }

          for(size_t i = 0; i < args_range; i++) {
            std::cerr << "[vm/CallSite#execute] Hooked arg is " << each_hooked_arg->get(state,i)->to_string(state) << "\n";
            ary->set(state, i, each_hooked_arg->get(state, i));
          }

          Arguments updated_args(args.name(), ary);
          updated_args.set_recv(original_recv);

          if (block_given) {
            std::cerr << "[vm/CallSite#execute] Original args does have block. Setting it on new args.\n";
            updated_args.set_block(each_hooked_arg->get(state, each_hooked_arg->size() - 1));
          }

          std::cerr << "[vm/CallSite#execute] Now calling original.\n";
          return (*executor_)(state, this, call_frame, updated_args);
        }
      }

      return (*executor_)(state, this, call_frame, args);
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

