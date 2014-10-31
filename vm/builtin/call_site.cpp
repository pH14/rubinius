#include "arguments.hpp"
#include "builtin/class.hpp"
#include "builtin/call_custom_cache.hpp"
#include "builtin/call_site.hpp"
#include "builtin/call_unit.hpp"
#include "builtin/exception.hpp"
#include "builtin/executable.hpp"
#include "builtin/mono_inline_cache.hpp"
#include "builtin/object.hpp"
#include "builtin/poly_inline_cache.hpp"
#include "call_frame.hpp"
#include "global_cache.hpp"
#include "lookup_data.hpp"
#include "object_utils.hpp"
#include "ontology.hpp"

#include <sstream>

namespace rubinius {

  void CallSite::init(STATE) {
    GO(call_site).set(ontology::new_class(state, "CallSite", G(object), G(rubinius)));
    G(call_site)->set_object_type(state, CallSiteType);
  }

  CallSite* CallSite::empty(STATE, Symbol* name, Executable* executable, int ip) {
    CallSite* cache =
      state->new_object_dirty<CallSite>(G(call_site));
    cache->name_ = name;
    cache->executor_ = empty_cache;
    cache->fallback_ = empty_cache;
    cache->updater_  = empty_cache_updater;
    cache->executable(state, executable);
    cache->ip_ = ip;
    return cache;
  }

  Integer* CallSite::ip_prim(STATE) {
    return Integer::from(state, ip_);
  }

  Object* CallSite::empty_cache_custom(STATE, CallSite* call_site, CallFrame* call_frame,
                                          Arguments& args)
  {
    Object* const recv = args.recv();

    Array*  ary = Array::create(state, args.total() + 2);
    ary->set(state, 0, recv);
    ary->set(state, 1, call_site->name_);

    for(size_t i = 0; i < args.total(); i++) {
      ary->set(state, i + 2, args.get_argument(i));
    }

    Object* ret = G(rubinius)->send(state, call_frame, state->symbol("bind_call"), ary);

    if(CallUnit* cu = try_as<CallUnit>(ret)) {
      CallCustomCache* cache = CallCustomCache::create(state, call_site, cu);
      call_site->update_call_site(state, cache);
      return cu->execute(state, call_frame, cu, cu->executable(), cu->module(), args);
    } else {
      Exception::internal_error(state, call_frame, "bind_call must return CallUnit");
      return 0;
    }
  }

  Object* CallSite::empty_cache(STATE, CallSite* call_site, CallFrame* call_frame,
                                   Arguments& args)
  {
    Object* recv = args.recv();
    Class*  const recv_class  = recv->direct_class(state);

    // if(recv->is_secure_context_p()) {
    //   // std::cout << "[vm/CallSite#empty_cache] Receiver has a secure context.\n";
    //   recv = recv->get_secure_context_prim(state);
    // }

    LookupData lookup(call_frame->self(), recv->lookup_begin(state), G(sym_public));
    Dispatch dis(call_site->name());

    if(!dis.resolve(state, call_site->name(), lookup)) {
      if(!lookup_method_missing(state, call_frame, args,
          dis, call_frame->self(), recv->lookup_begin(state))) {
        std::cerr << "[vm/CallSite#empty_cache] Couldn't look up method missing\n";// << res->to_s(state, false) << "\n";
        return NULL;
      }
      // std::cerr << "[vm/CallSite#empty_cache] Couldn't resolve with dispatch\n";// << res->to_s(state, false) << "\n";
    }

    call_site->update(state, recv_class, dis);

    Executable* meth = dis.method;

    // if (recv->is_secure_context_p()) {
    //   if (CompiledCode* compiledCode = try_as<CompiledCode>(meth)) {
    //     std::cerr << "[vm/call_site#empty_cache] Call site has total args: " << compiledCode->total_args()->to_native() << " and " << compiledCode->required_args()->to_native() << " and arity " << compiledCode->arity()->to_uint() << "\n";
    //   } else {
    //     std::cerr << "[vm/call_site#empty_cache] Could not coerce meth to compiled code\n";
    //   }
    // }

    // std::cerr << "[vm/call_site#empty_cache] Call site machine code has total args: " << machine_code->total_args << " req " << machine_code->required_args << " post_args " << machine_code->post_args << " splat pos " << machine_code->splat_position << " stack size " << machine_code->stack_size << "\n";

    Module* mod = dis.module;

    // std::cout << "[vm/CallSite#empty_cache] Handling symbol " << call_site->name()->cpp_str(state) << "\n";
    Object* res;

    if(meth->custom_call_site_p()) {
      CallSiteInformation info(call_site->executable(), call_site->ip());
      state->set_call_site_information(&info);
      res = meth->execute(state, call_frame, meth, mod, args);
      state->set_call_site_information(NULL);
      // return res;
    } else {
      res = meth->execute(state, call_frame, meth, mod, args);
    }

    // std::cout << "[vm/CallSite#empty_cache] " << res->to_s(state, false) << "\n";
    return res;
  }

  Object* CallSite::empty_cache_private(STATE, CallSite* call_site, CallFrame* call_frame,
                                   Arguments& args)
  {
    Object* const recv = args.recv();
    Class* const recv_class = recv->direct_class(state);

    LookupData lookup(call_frame->self(), recv->lookup_begin(state), G(sym_private));
    Dispatch dis(call_site->name());

    if(!dis.resolve(state, dis.name, lookup)) {
      if(!lookup_method_missing(state, call_frame, args,
          dis, call_frame->self(), recv->lookup_begin(state))) {
        return NULL;
      }
    }

    call_site->update(state, recv_class, dis);

    Executable* meth = dis.method;
    Module* mod = dis.module;

    if(meth->custom_call_site_p()) {
      CallSiteInformation info(call_site->executable(), call_site->ip());
      state->set_call_site_information(&info);
      Object* res = meth->execute(state, call_frame, meth, mod, args);
      state->set_call_site_information(NULL);
      return res;
    } else {
      return meth->execute(state, call_frame, meth, mod, args);
    }
  }

  Object* CallSite::empty_cache_vcall(STATE, CallSite* call_site, CallFrame* call_frame,
                                         Arguments& args)
  {

    Object* const recv = args.recv();
    Class* const recv_class = recv->direct_class(state);

    LookupData lookup(call_frame->self(), recv->lookup_begin(state), G(sym_private));
    Dispatch dis(call_site->name());

    if(!dis.resolve(state, call_site->name(), lookup)) {
      dis.method_missing = eVCall;
      if(!lookup_method_missing(state, call_frame, args,
          dis, call_frame->self(), recv->lookup_begin(state))) {
        return NULL;
      }
    }

    call_site->update(state, recv_class, dis);

    Executable* meth = dis.method;
    Module* mod = dis.module;

    if(meth->custom_call_site_p()) {
      CallSiteInformation info(call_site->executable(), call_site->ip());
      state->set_call_site_information(&info);
      Object* res = meth->execute(state, call_frame, meth, mod, args);
      state->set_call_site_information(NULL);
      return res;
    } else {
      return meth->execute(state, call_frame, meth, mod, args);
    }
  }

  Object* CallSite::empty_cache_super(STATE, CallSite* call_site, CallFrame* call_frame,
                                   Arguments& args)
  {
    Symbol* original_name = call_frame->original_name();
    if(call_site->name_ != original_name) {
      call_site->name_ = original_name;
      args.set_name(call_site->name_);
    }

    Object* const recv = args.recv();
    Class* const recv_class = recv->direct_class(state);
    Module* const start = call_frame->module()->superclass();

    LookupData lookup(call_frame->self(), start, G(sym_private));
    Dispatch dis(call_site->name());

    if(start->nil_p() || !dis.resolve(state, call_site->name(), lookup)) {

      LookupData missing_lookup(call_frame->self(), recv->lookup_begin(state), G(sym_private));
      Dispatch missing_dis(G(sym_method_missing));

      if(!missing_dis.resolve(state, G(sym_method_missing), missing_lookup)) {
        std::ostringstream msg;
        msg << "no method_missing for ";
        msg << recv_class->to_string(state);
        msg << "#" << call_site->name()->to_string(state);

        Exception::internal_error(state, call_frame, msg.str().c_str());
        return 0;
      }

      args.unshift(state, call_site->name());
      dis.method = missing_dis.method;
      dis.module = missing_dis.module;
      dis.method_missing = eSuper;
      state->vm()->set_method_missing_reason(dis.method_missing);
      state->vm()->global_cache()->add_seen(state, call_site->name());
    }

    call_site->update(state, recv_class, dis);

    Executable* meth = dis.method;
    Module* mod = dis.module;

    if(meth->custom_call_site_p()) {
      CallSiteInformation info(call_site->executable(), call_site->ip());
      state->set_call_site_information(&info);
      Object* res = meth->execute(state, call_frame, meth, mod, args);
      state->set_call_site_information(NULL);
      return res;
    } else {
      return meth->execute(state, call_frame, meth, mod, args);
    }
  }

  void CallSite::empty_cache_updater(STATE, CallSite* call_site, Class* klass, Dispatch& dispatch) {
    MonoInlineCache* cache = MonoInlineCache::create(state, call_site, klass, dispatch);
    call_site->update_call_site(state, cache);
  }

  bool CallSite::update_and_validate(STATE, CallFrame* call_frame, Object* recv, Symbol* vis, int serial) {

    Class* const recv_class = recv->direct_class(state);

    if(MonoInlineCache* mono = try_as<MonoInlineCache>(this)) {
      if(recv_class->data_raw() == mono->receiver_data_raw()) {
        return mono->method()->serial()->to_native() == serial;
      }
    }

    if(PolyInlineCache* cache = try_as<PolyInlineCache>(this)) {
      InlineCacheEntry* ice = cache->get_entry(recv_class);
      if(likely(ice)) return ice->method()->serial()->to_native() == serial;
    }

    LookupData lookup(call_frame->self(), recv->lookup_begin(state), G(sym_public));
    Dispatch dis(name_);

    if(dis.resolve(state, name_, lookup)) {
      update(state, recv_class, dis);
      return dis.method->serial()->to_native() == serial;
    }
    return false;
  }

  bool CallSite::lookup_method_missing(STATE, CallFrame* call_frame, Arguments& args, Dispatch& dis, Object* self, Module* begin) {
    LookupData missing_lookup(self, begin, G(sym_private));
    Dispatch missing_dis(G(sym_method_missing));

    if(!missing_dis.resolve(state, G(sym_method_missing), missing_lookup)) {
      std::ostringstream msg;
      msg << "no method_missing for ";
      msg << begin->to_string(state);
      msg << "#" << dis.name->to_string(state);

      Exception::internal_error(state, call_frame, msg.str().c_str());
      return false;
    }

    args.unshift(state, dis.name);
    dis.method = missing_dis.method;
    dis.module = missing_dis.module;
    state->vm()->set_method_missing_reason(dis.method_missing);
    state->vm()->global_cache()->add_seen(state, dis.name);
    return true;
  }

  void CallSite::Info::mark(Object* obj, ObjectMark& mark) {
    auto_mark(obj, mark);
  }

}
