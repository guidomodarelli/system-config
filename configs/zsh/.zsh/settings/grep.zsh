if [[ $(uname) = "Darwin" ]]; then
	export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"

	echo "test" | grep -P "test" &> /dev/null

	if [[ $? != 0 ]]; then
		echo "brew install grep"
	fi
fi
