Use

    rake --tasks
    
to see the testing related tasks.

Briefly:

* the unit tests user fibers to precisely control switching and focus testing on data structure manipulation in multiple concurrent contexts; also, most of the supporting libraries are mocked out.

* the system tests use threads and processes to test that the various client and server processes work correctly together. Nothing is mocked out. However, we still try to isolate operations in time, to some degree, to improve repeatability and debugging.

* the stress tests are like system tests: they let the ruby thread scheduler (hence the native thread scheduler) take control. Unlike the system tests they try to maximize concurrency. Since we can't guarantee precise sequences of events, we rely on lots of them to find errors.


