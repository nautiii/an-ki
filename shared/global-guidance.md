# Global

## Anti-Patterns (DON'T)

You must avoid generating:

* Firebase calls inside widgets
* large widgets with logic
* repeated mapping logic
* use of `setState` for global data
* nested FutureBuilder / StreamBuilder

Never add uid to the 'updateBirthday' method, as uid is already being passed in the constructor of
the
class. This is to ensure that the method remains focused on its primary responsibility, which is
updating the birthday information, without being concerned with user identification. By keeping the
method's parameters limited to what is necessary for its functionality, we promote cleaner code and
reduce the risk of unintended side effects or confusion about the method's purpose.