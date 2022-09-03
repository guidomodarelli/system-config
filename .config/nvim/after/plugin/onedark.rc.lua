local status, onedark = pcall(require, 'onedark')
if (not status) then return end
onedark.setup {
  style = 'darker',
  code_style = {
    comments = 'italic',
    keywords = 'italic,bold',
    functions = 'bold',
    strings = 'none',
    variables = 'none'
  },
}

onedark.load()
