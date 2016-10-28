#recipe specificaion
import tables

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
var recipeTypes* = initTable[string, seq[string]]()
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
# kept here for backwards compatibillity
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
const configure =["pre_patch()","pre_build()", "pre_install()", "pre_link()", "post_install()"]
const cabal = ("pre_patch()", "pre_build()", "pre_install())", "post_install()")
const makefile = ("pre_patch())", "pre_build())", "pre_install())", "pre_link())", "post_install()")
const manifest = ["pre_patch()", "pre_install()", "pre_link()", "post_install()"]
const perl = makefile#this is a reference to another build type
const python = ("pre_patch()", "pre_build()", "pre_install()", "pre_link()", "post_install()")
const scons= ("pre_patch()", "pre_build()", "pre_install()", "pre_link()", "post_install()")
const xmkmf= ("pre_patch()", "pre_build()", "pre_install()", "pre_link()", "post_install()")
const low_level_hooks=("do_fetch()", "do_unpack()", "do_patch()", "do_configuration()",
                       "do_build()", "do_install()")
