/*
Copyright 2016 Mark Fisher

This file is part of DRete.

Foobar is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Foobar is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with DRete.  If not, see <http://www.gnu.org/licenses/>.
*/

module drete.drete;

import drete.util;

import core.vararg;

import std.algorithm,
	std.array,
	std.traits,
	std.typetuple;

debug(Rete) {
	import std.stdio,
		std.conv;
}

interface IRule {
	alias bool delegate (void*[]) Condition;
	alias void delegate (void*[]) Application;
	
	const(ClassInfo)[] parameterTypes () const;
	bool condition(IBoundParameter[] bindings) const;
	void apply(IBoundParameter[] bindings);
};

interface IParameterBinding {
	const(IRule) rule() const;
	int index() const;
	const(ClassInfo) boundType() const;
};

interface IBoundParameter {
	const(IParameterBinding) binding() const;
	const(void*) item() const;
	void* item();
};

class Rete {

	alias void* Item;

	static class Rule : IRule {
		const(ClassInfo)[] ptypes;

		Condition cond;
		Application application;

		const(ClassInfo)[] parameterTypes () const {
			return ptypes;
		}
		bool condition(IBoundParameter[] bindings) const {
			assert(bindings.length == ptypes.length);
			auto param = bindings.map!(a=>a.item());
			debug(Rete)writeln("Rule cond: "~parameterTypes.to!string~" "~param.to!string~" "~cond.to!string);
			return cond(param.array);
		}
		void apply(IBoundParameter[] bindings) {
			assert(bindings.length == ptypes.length);
			auto param = bindings.map!(a=>a.item());
			application(param.array);
		}
		this(const(ClassInfo)[] param,Condition c,Application a) {
			this.ptypes = param;
			this.cond = c;
			this.application = a;
			debug(Rete) writeln("New rule: "~this.ptypes.to!string);
		}
	};

	static class ParameterBinding : IParameterBinding {
		const(Rule) _rule;
		int _index;
		const(ClassInfo) _boundType;
		const(IRule) rule() const {
			return this._rule;
		}
		int index() const {
			return this._index;
		}
		const(ClassInfo) boundType() const {
			return this._boundType;
		}
		this(const(Rule) r,int index,const(ClassInfo) cls) {
			this._rule = r;
			this._index = index;
			this._boundType = cls;
		}
	};

	static class BoundParameter : IBoundParameter {
		ParameterBinding _binding;
		Item _item;
		const(IParameterBinding) binding() const {
			return this._binding;
		}
		void* item() {
			return this._item;
		}
		const(void*) item() const {
			return this._item;
		}
	};

	static class BindingSet {
		Rule rule;
		BoundParameter[int] bound;

		int[] unboundParams() const {
			debug(Rete)writeln("unboundParams "~bound.keys.to!string~" "~rule.parameterTypes.to!string);
			if(bound.length==rule.parameterTypes.length) return [];
			int[] r = [];
			int i=0;
			foreach(x;rule.parameterTypes) {
				if(!(i in bound))r~=i;
				i++;
			}
			debug(Rete)writeln("unbound: "~r.to!string);
			return r;
		}
		
		bool matchesAll() const {
			return (bound.length==rule.parameterTypes.length);
		}

		bool cond() const {
			auto ar = bound.values.map!(a=>cast(IBoundParameter)a).array;
			debug(Rete)writeln("bindingset cond: "~rule.parameterTypes.to!string~" "~bound.keys.to!string~" "~ar.to!string);
			return rule.condition(ar);
		}

		void apply() {
			rule.apply(bound.values.map!(a=>cast(IBoundParameter)a).array);
		}

		void setBinding(BoundParameter param) {
			bound[param._binding.index]=param;
			debug(Rete)writeln("setBinding "~param._binding.index.to!string~" "~bound[param._binding.index].to!string);
		}

		this() {
		}

		this(BindingSet parent) {
			this.rule = parent.rule;
			this.bound = parent.bound.dup;
		}
	};

	Rule[][const(ClassInfo)] rulesByClass; // set of rules hashed against the types of each parameter.
	
	Item[][const(ClassInfo)] itemsByClass;
	//const(ClassInfo)[][const(Item)] classesByItem;
	
	ParameterBinding[][const(ClassInfo)]bindingsByClass;
	ParameterBinding[][const(Rule)]bindingsByRule;

	BindingSet[] matchingSets; // bindings that have a full set of matching parameters.
	

	/**
	 * Returns all rules with bindings to a specified class.
	 */
	Rule[] rulesForClass(const(ClassInfo) cls) {
		Rule[] result;

		foreach(k,v;rulesByClass) {
			if(cls == k) result ~= v;
		}
		void f(const(ClassInfo) a) {
			result~=rulesForClass(a);
		}
		cls.eachSuper!(f);
		debug(Rete) writeln("rulesForClass: "~cls.to!string~" "~result.to!string);
		return result;
	}

	Rule rule(const(ClassInfo)[] ptypes,IRule.Condition cond,IRule.Application app) {
		auto r = new Rule(ptypes,cond,app);
		addRule(r);
		return r;
	}
	Rule rule(T...)(bool delegate(T) cond,void delegate(T) app) {
		const(ClassInfo)[] cls;
		foreach(t;T) {
			cls ~= typeid(t).info;
		}
		auto c = delegate bool (void*[] args) {
			debug(Rete)writeln("Condition "~args.to!string);
			T _a;
			int i=0;
			foreach(ref t;_a) {
				t = cast(typeof(t))args[i++];
				debug(Rete)writeln("Condition param "~t.to!string);
			}
			debug(Rete)writeln("Condition params ",_a);
			return cond(_a);
		};
		auto a = delegate void (void*[] args) {
			T _a;
			int i=0;
			foreach(ref t;_a) {
				t = cast(typeof(t))args[i++];
				debug(Rete)writeln("Application param "~t.to!string);
			}
			app(_a);
		};
		auto r = new Rule(cls,c,a);
		addRule(r);
		return r;
	}
	void tell(T)(T item) {
		Item _item = cast(Item) item;
		debug(Rete) writeln("tell: "~_item.to!string~" "~typeid(T).to!string);
		//if(_item in classesByItem) {
		//} else {
		//	addItem(item);
		//}
		addItem(item);
	}
	void addRule(Rule r) {
		debug(Rete) writeln("Adding rule: "~r.to!string~" "~r.parameterTypes.to!string);
		foreach(a;r.parameterTypes) {
			debug(Rete) writeln("Adding rule/class: "~a.to!string~" - "~r.to!string);
			if(a in rulesByClass){
				rulesByClass[a]~=r;
			} else {
				rulesByClass[a]=[r];
			}
		}
		rulesByClass.rehash;
	}
	void addItem(T)(T item) {
		debug(Rete)writeln("addItem "~" "~item.to!string);
		addClass(typeid(T));
		Item _item = cast(Item) item;
		//classesByItem[_item] = [typeid(T)];
		if(typeid(T) in itemsByClass) {
			itemsByClass[typeid(T)] ~= _item;
		} else {
			itemsByClass[typeid(T)] = [ _item ];
		}

		alias types = TransitiveBaseTypeTuple!T;
		foreach(type;types) {
			auto a = typeid(type).info;
			debug(Rete)writeln("Add super "~a.to!string);
			addClass(a);
			Item _i = cast(Item)(cast(type)item);
			if(a in itemsByClass) {
				itemsByClass[a] ~= _i;
			} else {
				itemsByClass[a] = [ _i ];
			}
		}
		foreach(a;bindingsForClass(typeid(T))) {
			registerBoundItem(a,_item);
		}
		itemsByClass.rehash;
		debug(Rete)writeln("done addItem "~" "~item.to!string);
	}
	void delItem(T)(T item) {
		Item _item = cast(Item) item;
		classesByItem.remove(_item);
		itemsByClass[typeid(T)].remove(_item);
		alias types = TransitiveBaseTypeTuple!T;
		foreach(type;types) {
			itemsByClass[typeid(type)].remove(_item);
		}
		auto b = bindingsForClass(typeid(T));
		b.each!(a=>unregisterBoundItem(a,_item));
		itemsByClass.rehash;
		classesByItem.rehash;
	}
	void addClass(const(ClassInfo) cls) {
		auto rules = rulesForClass(cls);
		debug(Rete) writeln("Adding class rules: "~cls.to!string~" - "~rules.to!string);
		foreach(r;rules) {
			int i=0;
			foreach(p;r.parameterTypes) {
				if(inheritsFrom(cls,p)) {
					debug(Rete) writeln("Adding class binding: "~cls.to!string~" "~i.to!string~" "~r.to!string);
					addBinding(r,i,cls);
				}
				i++;
			}
		}
	}
	/**
	 * Called when an item is found to match a parameter binding for a rule.  Create BoundSets for each potential match.
	 */
	void registerBoundItem(ParameterBinding binding,Item item) {
		debug(Rete)writeln("registerBoundItem "~" "~binding.to!string~" "~item.to!string);
		BindingSet s = new BindingSet;
		BoundParameter p = new BoundParameter;
		p._binding = binding;
		p._item = item;
		s.rule = cast(Rule)binding.rule;
		s.bound[binding.index] = p;
		addBindingSet(s);		
		createMatchSets(s);
		debug(Rete)writeln("done registerBoundItem "~" "~binding.to!string~" "~item.to!string);
	}
	void unregisterBoundItem(ParameterBinding binding,Item item) {
		// TODO
	}
	void createMatchSets(BindingSet parent) {
		debug(Rete)writeln("createMatchSets "~" "~parent.to!string);
		// find unmatched parameters in the set.
		int[] ub = parent.unboundParams();
		debug(Rete)writeln("createMatchSets ubbound "~" "~ub.length.to!string);
		if(ub.length == 0) return;

		// Fill in the first unbound parameter and recur.
		int u = ub[0];
		const(ClassInfo) cls = parent.rule.parameterTypes[u];
		
		debug(Rete)writeln("createMatchingSet for "~" "~u.to!string~" "~cls.to!string);
		if(!(cls in itemsByClass)) {
			return;
		}
		
		Item[] items = itemsByClass[cls];
		debug(Rete)writeln("createMatchingSet items "~" "~cls.to!string~" "~items.to!string);
		foreach(item;items) {
			BindingSet s = new BindingSet(parent);
			BoundParameter p = new BoundParameter;
			debug(Rete)writeln("createMatchingSet item "~" "~item.to!string~" "~p.to!string);
			auto binding = getBindingForRule(s.rule,u);
			p._binding = binding;
			p._item = item;
			debug(Rete)writeln("createMatchingSet item binding "~" "~item.to!string~" "~binding.index.to!string~" "~binding.to!string);
			s.setBinding(p);
			addBindingSet(s);
			createMatchSets(s);
		}
		debug(Rete)writeln("done createMatchingSet "~" "~parent.to!string);
	}
	void addBindingSet(BindingSet s) {
		debug(Rete)writeln("addBindingSet "~" "~s.to!string);
		if(s.matchesAll) {
			matchingSets ~= s;
			debug(Rete)writeln("Matched "~" "~matchingSets.to!string);
		}
	}

	void addBinding(Rule r,int index,const(ClassInfo) cls) {
		if(cls in rulesByClass) {
			rulesByClass[cls] ~= r;
		} else {
			rulesByClass[cls] = [r];
		}
		ParameterBinding n = new ParameterBinding(r,index,cls);
		if(cls in bindingsByClass) {
			bindingsByClass[cls] ~= n;
		} else {
			bindingsByClass[cls] = [n];
		}
		if(r in bindingsByRule) {
			bindingsByRule[r] ~= n;
		} else {
			bindingsByRule[r] = [n];
		}
		rulesByClass.rehash;
		bindingsByClass.rehash;
		bindingsByRule.rehash;
	}
	ParameterBinding getBindingForRule(Rule r,int index) {
		debug(Rete)writeln("getBindingForRule "~" "~r.to!string~" "~index.to!string);
		auto b = bindingsByRule[r];
		foreach(a;b) {
			if(a.index == index) return a;
		}
		return null;
	}
	ParameterBinding[] bindingsForClass(const(ClassInfo) cls) {
		ParameterBinding[] result = [];
		if(cls in bindingsByClass) {
			result ~= bindingsByClass[cls];
		}
		void f(const(ClassInfo) a) {
			result~=bindingsForClass(a);
		}
		cls.eachSuper!f;
		debug(Rete)writeln("bindingsForClass "~cls.to!string~" "~result.to!string);
		return result;
	}
	ulong cycle() {
		BindingSet[] firing = [];
		foreach(m;matchingSets) {
			debug(Rete)writeln("testing set: "~m.to!string);
			if(m.cond()==true) {
				debug(Rete)writeln("firing: "~m.to!string);
				firing ~= m;
			}
		}
		firing.each!(f=>f.apply());
		return firing.length;
	}

};

unittest {
	class MyTest {
	}
	class MyTest2 {
	}
	auto rete = new Rete;
	bool rule1CondIsFired = false;
	
	auto rule1 = rete.rule([typeid(MyTest),typeid(MyTest2)],delegate bool (void*[] a){
		// conditon
		assert(cast(MyTest)a[0] !is null);
		assert(cast(MyTest2)a[1] !is null);
		rule1CondIsFired = true;
		return false;
	},(void*[] a){
		// application
		assert(false);
	});
	
	MyTest myTest = new MyTest;
	MyTest2 myTest2 = new MyTest2;

	rete.tell(myTest);
	rete.tell(myTest2);

	rete.cycle();

	assert(rule1CondIsFired == true);
}

unittest {
	class MyTest {
	}
	class MyTest2 {
	}
	auto rete = new Rete;
	bool rule1CondIsFired = false;
	bool rule1ApplyIsFired = false;

	auto rule1 = rete.rule([typeid(MyTest),typeid(MyTest2)],delegate bool (void*[] a){
		// Condition
		assert(cast(MyTest)a[0] !is null);
		assert(cast(MyTest2)a[1] !is null);
		rule1CondIsFired = true;
		return true;
	},(void*[] a){
		// Application
		assert(cast(MyTest)a[0] !is null);
		assert(cast(MyTest2)a[1] !is null);
		rule1ApplyIsFired = true;
	});

	MyTest myTest = new MyTest;
	MyTest2 myTest2 = new MyTest2;

	rete.tell(myTest);
	rete.tell(myTest2);

	rete.cycle();

	assert(rule1CondIsFired == true);
	assert(rule1ApplyIsFired == true);
}


unittest {
	class MyTest {
		int value = 10;
	}
	class MyTest2 {
		int value = 20;
	}
	auto rete = new Rete;
	auto rule = rete.rule!(MyTest,MyTest2)((a,b) {
		assert(a !is null);
		assert(b !is null);
		return a.value < b.value;
	}, (a,b) {
		assert(a !is null);
		assert(b !is null);
		a.value += 10;
		b.value -= 10;
	});

	MyTest myTest = new MyTest;
	MyTest2 myTest2 = new MyTest2;

	rete.tell(myTest);
	rete.tell(myTest2);

	rete.cycle();
	assert(myTest.value == 20);
	assert(myTest2.value == 10);
}


unittest {
	class MyBase {
		int value = 10;
	}
	class MyTest : MyBase {
	}
	class MyTest2 {
		int value = 20;
	}
	auto rete = new Rete;
	auto rule = rete.rule!(MyBase,MyTest2)((a,b) {
		assert(a !is null);
		assert(b !is null);
		return a.value < b.value;
	}, (a,b) {
		assert(a !is null);
		assert(b !is null);
		a.value += 10;
		b.value -= 10;
	});

	MyTest myTest = new MyTest;
	MyTest2 myTest2 = new MyTest2;

	rete.tell(myTest);
	rete.tell(myTest2);

	rete.cycle();
	assert(myTest.value == 20);
	assert(myTest2.value == 10);
}

unittest {
	interface MyBase {
		int value();
	}
	class MyTest : MyBase {
		int _value = 10;
		int value() {
			return _value;
		}
	}
	class MyTest2 {
		int value = 20;
	}
	auto rete = new Rete;
	auto rule = rete.rule!(MyBase,MyTest2)((a,b) {
		assert(a !is null);
		assert(b !is null);
		return a.value < b.value;
	}, (a,b) {
		assert(a !is null);
		assert(b !is null);
		b.value -= 10;
	});

	MyTest myTest = new MyTest;
	MyTest2 myTest2 = new MyTest2;

	rete.tell(myTest);
	rete.tell(myTest2);

	rete.cycle();
	assert(myTest.value == 10);
	assert(myTest2.value == 10);
}

