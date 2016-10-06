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
along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
*/

module drete.util;

import std.algorithm;

debug(Util) import std.stdio, std.conv;

bool inheritsFrom(const(ClassInfo) t,const(ClassInfo) from) {
	if(t == from) return true;
	if(t.base !is null && t.base.inheritsFrom(from)==true) return true;
	if(t.interfaces !is null) foreach(i;t.interfaces.map!(a=>a.classinfo)) {
		if(i.inheritsFrom(from)==true) return true;
	}
	return false;
}

void eachSuper(alias T)(const(ClassInfo) cls) {
	debug(Util)writeln("eachSuper "~cls.to!string);
	if(cls.interfaces !is null) foreach(i;cls.interfaces.map!(a=>a.classinfo)) {
		i.eachSuper!T;
		T(i);
	}
	if(cls.base !is null) {
		cls.base.eachSuper!T;
		T(cls.base);
	}
}

unittest {
	import std.stdio,std.conv;

	class MyBase {
	}

	class MyTest : MyBase {
	}
	int doneSuper = 0;
	/*typeid(MyTest).eachSuper!(a=>{
		writeln("Super of MyTest: "~a.to!string);
		assert(typeid(a) == typeid(MyBase));
		doneSuper=true;
	});*/
	void f(const(ClassInfo) a) {
		debug(Util)writeln("Super of MyTest: "~a.to!string);
		//assert(typeid(a) == typeid(MyBase));
		doneSuper++;
	}
	eachSuper!(f)(typeid(MyTest));
	assert(doneSuper==2);
}

unittest {
	import std.stdio,std.conv;

	interface MyBase {
	}

	class MyTest : MyBase {
	}
	int doneSuper = 0;
	/*typeid(MyTest).eachSuper!(a=>{
	writeln("Super of MyTest: "~a.to!string);
	assert(typeid(a) == typeid(MyBase));
	doneSuper=true;
	});*/
	void f(const(ClassInfo) a) {
		debug(Util)writeln("Super of MyTest: "~a.to!string);
		//assert(typeid(a) == typeid(MyBase));
		doneSuper++;
	}
	eachSuper!(f)(typeid(MyTest));
	assert(doneSuper==2);
}

template Map(alias Func,args...) {
	static auto ref ArgCall(alias Func,alias arg)() { return Func(arg); }
	static if (args.length > 1) 
		alias Map = TypeTuple!(ArgCall!(Func,args[0]),Map!(Func,args[1..$]));
	else
		alias Map = ArgCall!(Func,args[0]);
}

