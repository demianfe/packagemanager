#Experimental work in progress, will change drastically in the future.

import os
import strutils
import tables

#recipe sections and their values
const gettingTheSource: array[10,string] = ["url",
                                            "urls",
                                            "mirror_url",
                                            "mirror_urls",
                                            "file",
                                            "files",
                                            "file_size",
                                            "file_sizes",
                                            "file_md5",
                                            "file_md5s"]

const versionControlSystems = [ "cvs",
                                "cvss",
                                "cvs_module",
                                "cvs_modules",
                                "cvs_opts",
                                "cvs_options",
                                "cvs_password",
                                "cvs_checkout_options",
                                "cvs_rsh",
                                "svn",
                                "svns",
                                "bzr",
                                "bzrs",
                                "git",
                                "gits",
                                "hg",
                                "hgs"]

#we create a sequence of the defined type above
var recipeTypes = initTable[string, seq[string]]()
recipeTypes.add("configure", @["configure_options", "autogen_before_configure","autogen","configure"])
recipeTypes.add("cabal", @["cabal_options","runhaskell"])
recipeTypes.add("cmake", @["cmake_options","cmake_variables"])
recipeTypes.add("makefile",@[])
recipeTypes.add("perl", @["perl_options","without"])
recipeTypes.add("python", @["python_options","build_script"])
recipeTypes.add("scons", @["scons_variables"])
recipeTypes.add("xmkmf",@[])
recipeTypes.add("manifest", @["manifest"])
recipeTypes.add("meta", @["include","part_of","update_each_settings"])
recipeTypes.add("other_options", @["compile_version", "environment",
                                   "uncompress", "unpack_files", "dir", "dirs", "docs",
                                   "create_dirs_first","keep_existing_target",
                                   "build_variables","install_variables","make_variables",
                                   "makefile","make","build_target","install_target",
                                   "do_build","do_install","needs_build_directory","needs_safe_linking",
                                   "override_default_options","post_install_message","sandbox_options",
                                   "symlink_options","unmanaged_files","with"])
#this will be deprecated or not used at all
#just kept here for backwards compatibillity
#we will avoid global variables at all costs
const systemVariables = [ "$goboExecutables",
                            "$goboHeaders",
                            "$goboModules",
                            "$goboLibraries",
                            "$goboPrograms",
                            "$goboSettings",
                            "$goboTemp",
                            "$goboVariable"]

const programVariables=["$target","$settings_target","$variable_target"]
#const base_options= []
const archs = ["arm", "cell", "i686", "x86_64"]
const configure =["pre_patch()",
                        "pre_build()",
                        "pre_install()",
                        "pre_link()",
                        "post_install()"]

const cabal = ("pre_patch()", "pre_build()", "pre_install())", "post_install()")
const makefile = ("pre_patch())", "pre_build())", "pre_install())", "pre_link())", "post_install()")
const manifest = ["pre_patch()", "pre_install()", "pre_link()", "post_install()"]
const perl = makefile#this is a reference to another build type
const python = ("pre_patch()", "pre_build()", "pre_install()", "pre_link()", "post_install()")
const scons= ("pre_patch()", "pre_build()", "pre_install()", "pre_link()", "post_install()")
const xmkmf= ("pre_patch()", "pre_build()", "pre_install()", "pre_link()", "post_install()")
const low_level_hooks=("do_fetch()", "do_unpack()", "do_patch()", "do_configuration()",
                       "do_build()", "do_install()")


#type for the Recipe itself to be passed around
type
  Recipe* = object
    properties*: Table[string, string]
    configurations*: Table[string, seq[string]]
    functions*: Table[string, seq[string]]
    dependencies*: Table[string, string]
    buildDependencies*: Table[string, string]
    description*: Table[string, string]
        
proc parseDependencies(dependenciesString: string): Table[string, string] =
  #TODO: handle useflgs
  #TODO: dependencies have minor and mayor versions
  var depsTable = initTable[string, string]()
  var dependencies: seq[string] = split(dependenciesString, "\n")
  for dep in dependencies:
    if dep.len > 0:
      var
        k,v: string
      if dep.find(" ") != -1:
        (k,v) = split(dep, " ")
        depsTable.add(k, v)
      else:
        depsTable.add(dep.strip(),"")
  return depsTable
      
proc parseRecipe(strFile: string): Recipe =
  #this prodecedure will call other procedures
  #to gather all recipe information needed on the
  #different stages of the build process.
  var result: Recipe
  var prevFunc: bool = false #flag so we know we are reading a function
  var prevConf: bool = false #flag so we know we are reading a configuration
  var functionName:string
  var configurationName:string
  var properties = initTable[string, string]()
  var configurations = initTable[string, seq[string]]()
  var functions = initTable[string, seq[string]]()
  var lines: seq[string] = split(strFile, "\n")
  for line in lines:
    #if line contans ´()´ is a function
    #if line contains only ´=(´ is a Compile configuration parameter
    #if line contains = is keyval like
    #this code may be too general
    if line.len > 0 and not line.startsWith("#"):
      #parses the recipe pairs of key=value attributes
      if (line.count("=")==1) and (line.find("(") == -1) and
        (line.find(")") == -1) and prev_func == false and prevConf == false:
        var
          name, value: string
        (name, value) = split(line, "=")
        properties.add(name.strip(), value)
      elif line.replace(" ","").find("()") != -1 and prev_func == false and prevConf == false:
        #finds a functions and treat following lines as part of the function
        #until the `}` function block end is found
        prevFunc = true 
        functionName = line[0 .. line.find("()") - 1]
        functions.add(functionName, @[])
      elif prevFunc == true and line.strip().find("}") == 0:
        #TODO: add more controls to find end of block
        prevFunc = false
      elif prevFunc == true:
        for fName, currentValue in pairs functions:
          if fName == functionName:
            functions[fName].add(line.strip())
            break
      else:
        var replacedString: string = line.replace(" ", "")
        if replacedString.find("=(") != -1 and replacedString.find("=(")+2 == replacedString.len and prevConf == false:
          prevConf = true
          configurationName = line.strip().replace("=(", "")
          configurations.add(configurationName, @[])
        elif replacedString.find(")") == 0 and not prevFunc:
          prevConf = false
          configurations[configurationName].add(line.strip())
        elif prevConf:
         configurations[configurationName].add(line.strip())
  
  result = Recipe(properties: properties,
                  configurations: configurations,
                  functions: functions)
  # echo result
  return result
  
proc parseDescription(descriptionString: string): Table[string, string] =
  const sections: array[5, string] = ["[Name]", "[Summary]",
                                      "[License]", "[Description]",
                                      "[Homepage]"]
  var index:int = 0
  var value: string
  var result = initTable[string, string]()
  let lines = descriptionString.split("\n")
  for line in lines:
    let section = line.subStr(line.find("["), line.find("]"))
    .replace("[", "")
    .replace("]", "")
    let value = line.subStr(line.find("]") + 1, len(line))
    result.add(section.strip(), value.strip())
  return result
  
proc getRecipeDirTree*(recipeDir: string): Recipe =
  #TODO: improve directory and file existence checking
  #reads the filepath and returns a the
  #directory files as strings
  var dependencies: Table[string, string]
  var recipe: Recipe
  if os.dirExists(recipeDir):
    var resourcesDir:string = recipeDir & "Resources/"
    if os.fileExists(recipeDir & "Recipe"):
       recipe = parseRecipe(readFile(recipeDir & "Recipe"))
    if os.dirExists(resourcesDir):
      if os.fileExists(resourcesDir & "Description"):
        recipe.description = parseDescription(readFile(resourcesDir & "Description"))
      if os.fileExists(resourcesDir & "BuildDependencies"):
        #echo readFile(resourcesDir & "BuildDependencies")
        recipe.buildDependencies = parseDependencies(readFile(resourcesDir & "BuildDependencies"))
        echo "TODO: BuildDependencies"
      if os.fileExists(resourcesDir & "BuildInformation"):
        echo "TODO: BuildInformation"
      if os.fileExists(resourcesDir & "Dependencies"):
        recipe.dependencies = parseDependencies(readFile(resourcesDir & "Dependencies"))
      if os.fileExists(resourcesDir & "Environment"):
        echo "TODO: Environment"
      #TODO: tasks
  return recipe
