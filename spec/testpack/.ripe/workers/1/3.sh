
# <foo.sh.erb>

exec 1>".ripe/workers/1/3.log" 2>&1

# Foo is certainly one of the most important prerequisites to Bar.

echo "$(cat "Sample1/foo_input.txt") For You" > "Sample1/foo_erb_output.txt"

echo "##.DONE.##"

# </foo.sh.erb>
