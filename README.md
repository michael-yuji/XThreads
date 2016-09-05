# XThreads

A threading library using pthread

## usage:

to create a thread pool - 
``` swift
let my_thread_pool = XThreadsPool(threads: your_number_of_threads_in_thread_pool)
```

to execute block async - 
``` swift 
my_thread_pool.execute { /* whatever in the block */ }"
```

to execute block by order - 
``` swift

let thread = XThread() /* a idenpendent thread */
thread.exec {
  /* first */
}

thread.exec {
  /* second */
}
```
