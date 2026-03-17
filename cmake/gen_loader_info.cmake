# ==========================================================================
# gen_loader_info.cmake
# 解析 proot-loader 二进制的符号表，计算 pokedata_workaround 偏移量
# 生成 loader-info.c（仅 ARM64 需要）
#
# 用法: cmake -DREADELF=<path> -DLOADER=<path> -DOUTPUT=<path> -P gen_loader_info.cmake
# 替代原始 GNUmakefile 中的 awk 脚本：
#   $(READELF) -s $< | awk -f loader/loader-info.awk > $@
# ==========================================================================

if(NOT READELF)
    message(FATAL_ERROR "READELF 未指定")
endif()
if(NOT LOADER)
    message(FATAL_ERROR "LOADER 未指定")
endif()
if(NOT OUTPUT)
    message(FATAL_ERROR "OUTPUT 未指定")
endif()

# 运行 readelf -s 获取符号表
execute_process(
    COMMAND "${READELF}" -s "${LOADER}"
    OUTPUT_VARIABLE READELF_OUTPUT
    RESULT_VARIABLE READELF_RESULT
    ERROR_VARIABLE READELF_ERROR
)

if(NOT READELF_RESULT EQUAL 0)
    message(FATAL_ERROR "readelf 执行失败: ${READELF_ERROR}")
endif()

# 解析 _start 和 pokedata_workaround 符号的地址
# readelf 输出格式:
#   Num:    Value          Size Type    Bind   Vis       Ndx Name
#     1: 0000002000000000   264 FUNC    GLOBAL DEFAULT     1 _start
#     2: 0000002000000108     0 NOTYPE  GLOBAL DEFAULT     1 pokedata_workaround
set(START_HEX "")
set(POKE_HEX "")

string(REPLACE "\n" ";" LINES "${READELF_OUTPUT}")
foreach(LINE IN LISTS LINES)
    # 匹配 _start 符号行
    if("${LINE}" MATCHES ":[ ]+([0-9a-fA-F]+).+ _start$")
        set(START_HEX "${CMAKE_MATCH_1}")
    endif()
    # 匹配 pokedata_workaround 符号行
    if("${LINE}" MATCHES ":[ ]+([0-9a-fA-F]+).+ pokedata_workaround$")
        set(POKE_HEX "${CMAKE_MATCH_1}")
    endif()
endforeach()

if("${START_HEX}" STREQUAL "")
    message(FATAL_ERROR "在 loader 中找不到 _start 符号")
endif()
if("${POKE_HEX}" STREQUAL "")
    message(FATAL_ERROR "在 loader 中找不到 pokedata_workaround 符号")
endif()

# 计算偏移量（pokedata_workaround 相对于 _start 的字节偏移）
math(EXPR OFFSET "0x${POKE_HEX} - 0x${START_HEX}")

# 生成 loader-info.c
file(WRITE "${OUTPUT}"
    "/* 由 CMake 自动生成 - 请勿手动编辑 */\n"
    "#include <unistd.h>\n"
    "const ssize_t offset_to_pokedata_workaround = ${OFFSET};\n"
)

message(STATUS "loader-info.c 已生成: offset = ${OFFSET} (0x${POKE_HEX} - 0x${START_HEX})")
