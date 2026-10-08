$lineCount = 12000

for ($lineIndex = 0; $lineIndex -lt $lineCount; $lineIndex++) {
  [Console]::Out.WriteLine(('stdout line {0} {1}' -f $lineIndex, ('x' * 32)))
  [Console]::Error.WriteLine(('stderr line {0} {1}' -f $lineIndex, ('y' * 32)))
}
