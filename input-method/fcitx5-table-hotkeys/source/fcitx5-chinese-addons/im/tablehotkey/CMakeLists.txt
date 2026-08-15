set(TABLEHOTKEY_SOURCES tablehotkey.cpp)
add_fcitx5_addon(tablehotkey ${TABLEHOTKEY_SOURCES})
target_link_libraries(tablehotkey Fcitx5::Core ${CMAKE_DL_LIBS})
install(FILES tablehotkey.conf DESTINATION "${CMAKE_INSTALL_DATADIR}/fcitx5/addon"
        COMPONENT config)
