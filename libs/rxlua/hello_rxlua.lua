require("examples/concat")
Rx = require("rx")

o1 = Rx.Observable.fromRange(3)
o2 = Rx.Observable.fromRange(3)

-- Rx.Observable.of(42):subscribe(print)

--o2:subscribe(print);
--o1.subscribe(print);

Rx.Observable.concat(o1, o2):subscribe(print)


