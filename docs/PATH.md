## PATH conflicts

It's possible to end up in situations where you have multiple `gleam` binaries in your `PATH`, and your system may use a version that you don't intend. Your `PATH` is a variable that tells your shell where to look for programs to run.

You can check where all of the versions are by running `which -a gleam`.

For example, a common conflict on macOS might be between a version installed by Homebrew, and a version installed manually to the /usr/local/gleam/bin directory.

```console
$ which -a gleam
/usr/local/gleam/bin/gleam
/opt/homebrew/bin/gleam
```

Whichever binary comes first in this list will be used when running `gleam` commands.

### Reordering your PATH

If you use bash or zsh, you can update your `PATH` like this:

```shell
# You might want to add this line to the end of your ~/.bashrc or ~/.zshrc file!
export PATH="/opt/homebrew/bin:$PATH"
```

If you use fish, you can update your `PATH` like this:

```shell
# You might want to add this line to the end of your ~/.config/fish/config.fish file!
fish_add_path "/opt/homebrew/bin"
```

<!-- prettier-ignore -->
> [!NOTE]
> If you ran install.sh with a `--prefix` flag, you can replace `/opt/homebrew` with whatever value you used there. Make sure to leave the `/bin` at the end!

Now we can observe that the order has changed:

```console
$ which -a gleam
/opt/homebrew/bin/gleam
/usr/local/gleam/bin/gleam
```
