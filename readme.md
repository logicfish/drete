DRete - Rete net in D (dlang)
=============================

Usage
=====

Adding Rules
------------

class MyClass {
}

class MyClass2 {
}

bool condition(MyClass a,MyClass2 b) {
	return true;
}

void application(MyClass a,MyClass2 b) {
	// ...
}

auto rete = new Rete;
rete.rule!(MyClass,MyClass2)(condition,application);

Adding 'facts'
------------

MyClass a = new MyClass;
rete.tell(a);

MyClass2 b = new MyClass2;
rete.tell(b);

Cycling
-------

This tells the rete to check which rules have fired and apply them.

int i = rete.cycle();

The return value is the count of rules which fired.
