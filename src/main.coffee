fs = require 'fs'
path = require 'path'
consola = require 'consola'

pkg = require '../package.json'
PREFIX = "[#{pkg.name}]"

pathRegex = /(['"`])((?:\.{1,2}\/|\/)[^"'`]*?\.coffee)\1/g;
suffixRegex = /(['"])(\.coffee)\1/g;

isImportContext = (fullText, offset) ->
  return false unless typeof fullText is 'string'

  lastLineBreak = fullText.lastIndexOf '\n', offset
  lineStart = if lastLineBreak is -1 then 0 else lastLineBreak + 1
  lineEnd = fullText.indexOf '\n', offset
  if lineEnd is -1
    lineEnd = fullText.length

  currentLine = fullText.substring lineStart, lineEnd

  trimmedLine = currentLine.trim()
  if trimmedLine.startsWith '//' or trimmedLine.startsWith '*' or trimmedLine.startsWith '/*'
    return false

  unless /\b(require|import)\b/.test currentLine
    return false

  i = offset - 1
  while i >= 0 and /\s/.test fullText[i]
    i--

  if fullText[i] is 's'
    i--

    if fullText[i] is 'i'
      i--

      if i < 0 or /\s/.test fullText[i]
        consola.trace "Skipping (found \"is\" keyword):", currentLine.substring(i + 1, offset + 10)
        return false

  return true

replaceExt = (options = {}) ->
  return (compilationResult) ->
    consola.info "#{PREFIX} Running..."

    { compiledFiles, config } = compilationResult

    # join
    if config.options?.join
      outputFile = path.resolve process.cwd(), config.output
      compiledFiles ?= []
      if fs.existsSync outputFile
        unless compiledFiles.includes outputFile
          compiledFiles.push outputFile
      else if fs.existsSync "#{outputFile}.js"
        outputFile += '.js'
        unless compiledFiles.includes outputFile
          compiledFiles.push outputFile

    if (not compiledFiles or compiledFiles.length is 0)
      consola.warn "#{PREFIX} No compiled files found to process."
      return

    processedCount = 0

    for file in compiledFiles
      isTargetFile = file.endsWith '.js' or (config.options?.join and path.resolve file is path.resolve process.cwd(), config.output)
      unless isTargetFile
        continue

      try
        content = fs.readFileSync file, 'utf-8'
        originalContent = content
        fileChanged = false

        content = content.replace pathRegex, (match, quote, matchedPath, offset, fullText) ->
          if isImportContext fullText, offset
            newPath = matchedPath.replace /\.coffee$/, '.js'
            if matchedPath isnt newPath
              fileChanged = true
              consola.trace "#{PREFIX} Replacing (path) in #{path.basename file}: #{matchedPath} -> #{newPath}"
              return "#{quote}#{newPath}#{quote}"
          return match

        content = content.replace suffixRegex, (match, quote, matchedPath, offset, fullText) ->
          if isImportContext fullText, offset
            newPath = matchedPath.replace /\.coffee$/, '.js'
            if matchedPath isnt newPath
              fileChanged = true
              consola.trace "#{PREFIX} Replacing (suffix) in #{path.basename file}: #{matchedPath} -> #{newPath}"
              return "#{quote}#{newPath}#{quote}"
          return match

        if fileChanged && content isnt originalContent
          fs.writeFileSync file, content, 'utf-8'
          processedCount++
      catch error
        consola.error "#{PREFIX} Failed to process file #{file}:", error

    if processedCount > 0
      consola.success "#{PREFIX} Processed and updated #{processedCount} file(s)."
    else
      consola.info "#{PREFIX} No files needed replacement."

module.exports = replaceExt
