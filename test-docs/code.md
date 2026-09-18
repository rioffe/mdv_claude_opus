# Code highlighting

Nine languages (K-05), Swift and SQL (R-38), an unknown fence, and prompt-aware fences (R-08, T-06, T-37).

```c
#include <stdio.h>
int main(void) { printf("%d\n", 42); return 0; } /* c */
```

```go
package main
func main() { s := "hi"; println(s) } // go
```

```rust
fn main() { let x: u32 = 7; println!("{}", x); } // rust
```

```bash
for f in *.txt; do echo "$f"; done # bash
```

```javascript
function f(a) { return `x${a}` + 3 } // js
```

```yaml
key: value
list:
  - 1
  - "two" # yaml
```

```toml
[table]
name = "x"
n = 3 # toml
```

```python
def f(x):
    return "s" + str(3)  # python
```

```ruby
def f(x)
  "s" + 3.to_s # ruby
end
```

```swift
// MARK: - Model
struct Counter {
    @Published var count: Int = 42
    func bump(by n: Int) -> String {
        guard let x = Optional(n) else { return "none" }
        return "count is \(count + x)"
    }
}
```

```sql
-- users and their orders
CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL);
SELECT u.name, COUNT(o.id) FROM users u JOIN orders o ON o.user_id = u.id WHERE u.name = 'alice' AND o.total > 100;
```

```postgresql
-- the same block, tagged postgresql, highlights identically to sql
SELECT u.name, COUNT(o.id) FROM users u JOIN orders o ON o.user_id = u.id WHERE u.name = 'alice' AND o.total > 100;
```

```brainfuck
+++++[>+++++<-]>.
```

```bash
$ ls -la
total 0
$ echo hi
hi
```

```console
$ ls -la
total 0
$ echo hi
hi
```

```fish
$ ls -la
total 0
$ echo hi
hi
```

```shell-session
$ ls -la
total 0
$ echo hi
hi
```

```powershell
$ ls -la
total 0
$ echo hi
hi
```
