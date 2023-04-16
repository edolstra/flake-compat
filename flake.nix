{ outputs = _: { __functor = _: src: (import ./. {inherit src;}).result; }; }
