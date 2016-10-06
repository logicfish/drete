DRete - Rete net in D (dlang)
=============================

Usage
=====

Adding Rules
------------

Each rule has a list of parameter types, and two delgates which accept those types as their argument list.
The first delegate returns a `bool` which indicates wether or not the rule is firing.  The second applies the rule.

```
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
```

Adding 'facts'
--------------

Facts are D objects which are used as bound parameters to a rule.  The rete determines which rules apply to which object and invokes the appropriate functions to apply
the rule to the object.

```
MyClass a = new MyClass;
rete.tell(a);

MyClass2 b = new MyClass2;
rete.tell(b);
```

Cycling
-------

This tells the rete to check which rules have fired and apply them.

```
int i = rete.cycle();
```

The return value is the count of rules which fired.

TODO
====

 - 
 - Asynchronous access.


