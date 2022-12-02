# romeo_juliet

A demonstration of using
[isolate_agents](https://pub.dev/packages/isolate_agents) to offload work from
the ui thread in Flutter.

## Getting Started

Execute the example with `flutter run`, all platforms are supported except web
since it lacks isolates.

## Explanation

The steps that the app takes are the following:

1) Load the text asset with all the decrypted messages, split them up, encrypt
   them and write them to the documents directory.
1) Query the platforms documents directory and store it on the agent.
1) Start a timer that will trigger a job that will read the encrypted message
   from the documents directory and decrypt it every second.
1) When the job is finished, if we have a new decrypted message add it to the
   cache on the root isolate and reload the scroll view.

How does this code differ from using Isolate directly?

1) There is much less code and a consistent interface to working with Isolates.

How does this code differ from using Flutter's `compute` function?

1) The Isolate lives long enough to be reused whenever we receive the request to
   decrypt a new message.
1) The Isolate can store state, in this case the documents directory, so it
   doesn't have to recalculate it on the Isolate or send it over every time.
