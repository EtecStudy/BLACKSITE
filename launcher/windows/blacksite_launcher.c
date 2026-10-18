#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#define GODOT_EXE L"C:\\Users\\kimfe\\Desktop\\GODOT\\Godot_v4.7.2-stable_win64.exe"
#define MAX_PATH_BUFFER 32768

/* Static buffers avoid a C runtime and large stack allocations in this tiny launcher. */
static wchar_t executable_path[MAX_PATH_BUFFER];
static wchar_t project_directory[MAX_PATH_BUFFER];
static wchar_t godot_command_line[MAX_PATH_BUFFER * 2];
static wchar_t scratch_path[MAX_PATH_BUFFER];
static wchar_t error_message[MAX_PATH_BUFFER + 256];
static wchar_t system_message[512];
/* Satisfy the GNU Windows CRT TLS index without pulling a C runtime into the launcher. */
unsigned long _tls_index = 0;

static int copy_wide(wchar_t *dst, size_t capacity, const wchar_t *src) {
    size_t i = 0;
    if (!dst || !src || capacity == 0) return 0;
    while (src[i] && i + 1 < capacity) {
        dst[i] = src[i];
        ++i;
    }
    dst[i] = L'\0';
    return src[i] == L'\0';
}

static int append_wide(wchar_t *dst, size_t capacity, const wchar_t *src) {
    size_t used = 0;
    if (!dst || !src || capacity == 0) return 0;
    while (used < capacity && dst[used]) ++used;
    if (used == capacity) return 0;
    return copy_wide(dst + used, capacity - used, src);
}

static int join_path(wchar_t *out, size_t capacity, const wchar_t *directory,
                     const wchar_t *leaf) {
    size_t n;
    if (!copy_wide(out, capacity, directory)) return 0;
    n = 0;
    while (out[n]) ++n;
    if (n > 0 && out[n - 1] != L'\\' && out[n - 1] != L'/') {
        if (n + 1 >= capacity) return 0;
        out[n++] = L'\\';
        out[n] = L'\0';
    }
    return append_wide(out, capacity, leaf);
}

static wchar_t *last_separator(wchar_t *text) {
    wchar_t *last = NULL;
    size_t i;
    for (i = 0; text[i]; ++i) {
        if (text[i] == L'\\' || text[i] == L'/') last = &text[i];
    }
    return last;
}

static void show_error(const wchar_t *title, const wchar_t *message) {
    MessageBoxW(NULL, message, title, MB_OK | MB_ICONERROR | MB_SETFOREGROUND);
}

static int require_file(const wchar_t *project_dir, const wchar_t *relative_path) {
    DWORD attributes;
    if (!join_path(scratch_path, MAX_PATH_BUFFER, project_dir, relative_path)) {
        show_error(L"BLACKSITE", L"O caminho do projeto e longo demais para ser validado.");
        return 0;
    }
    attributes = GetFileAttributesW(scratch_path);
    if (attributes == INVALID_FILE_ATTRIBUTES || (attributes & FILE_ATTRIBUTE_DIRECTORY)) {
        copy_wide(error_message, MAX_PATH_BUFFER + 256,
                  L"Arquivo necessario nao encontrado. Mantenha BLACKSITE.exe junto ao projeto:\n\n");
        append_wide(error_message, MAX_PATH_BUFFER + 256, scratch_path);
        show_error(L"BLACKSITE - arquivo ausente", error_message);
        return 0;
    }
    return 1;
}

static void launch_blacksite(void) {
    DWORD length = GetModuleFileNameW(NULL, executable_path, MAX_PATH_BUFFER);
    wchar_t *separator;
    DWORD godot_attributes;
    STARTUPINFOW startup = {0};
    PROCESS_INFORMATION process = {0};

    if (length == 0 || length >= MAX_PATH_BUFFER - 1) {
        show_error(L"BLACKSITE", L"Nao foi possivel localizar o arquivo BLACKSITE.exe.");
        ExitProcess(2);
    }
    separator = last_separator(executable_path);
    if (!separator) {
        show_error(L"BLACKSITE", L"Nao foi possivel localizar a pasta do inicializador.");
        ExitProcess(2);
    }
    *separator = L'\0';
    if (!copy_wide(project_directory, MAX_PATH_BUFFER, executable_path)) {
        show_error(L"BLACKSITE", L"O caminho da pasta do projeto e longo demais.");
        ExitProcess(2);
    }

    godot_attributes = GetFileAttributesW(GODOT_EXE);
    if (godot_attributes == INVALID_FILE_ATTRIBUTES ||
        (godot_attributes & FILE_ATTRIBUTE_DIRECTORY)) {
        copy_wide(error_message, MAX_PATH_BUFFER + 256,
                  L"Godot 4.7.2 nao foi encontrado no caminho configurado:\n\n");
        append_wide(error_message, MAX_PATH_BUFFER + 256, GODOT_EXE);
        append_wide(error_message, MAX_PATH_BUFFER + 256,
                    L"\n\nVerifique se o executavel grafico existe nesse caminho.");
        show_error(L"BLACKSITE - Godot ausente", error_message);
        ExitProcess(3);
    }

    if (!require_file(project_directory, L"project.godot") ||
        !require_file(project_directory, L"scenes\\menu\\main_menu.tscn") ||
        !require_file(project_directory, L"scenes\\maps\\sector.tscn") ||
        !require_file(project_directory, L"scenes\\player\\avatar.tscn") ||
        !require_file(project_directory, L"scripts\\networking\\menu.gd") ||
        !require_file(project_directory, L"scripts\\networking\\net.gd") ||
        !require_file(project_directory, L"scripts\\player\\sector.gd") ||
        !require_file(project_directory, L"scripts\\player\\avatar.gd") ||
        !require_file(project_directory, L"assets\\models\\blacksite_crate.glb")) {
        ExitProcess(4);
    }

    godot_command_line[0] = L'\0';
    if (!append_wide(godot_command_line, MAX_PATH_BUFFER * 2, L"\"") ||
        !append_wide(godot_command_line, MAX_PATH_BUFFER * 2, GODOT_EXE) ||
        !append_wide(godot_command_line, MAX_PATH_BUFFER * 2, L"\" --path \"") ||
        !append_wide(godot_command_line, MAX_PATH_BUFFER * 2, project_directory) ||
        !append_wide(godot_command_line, MAX_PATH_BUFFER * 2, L"\"")) {
        show_error(L"BLACKSITE", L"Nao foi possivel montar os argumentos para iniciar o projeto.");
        ExitProcess(5);
    }

    startup.cb = sizeof(startup);
    if (!CreateProcessW(GODOT_EXE, godot_command_line, NULL, NULL, FALSE,
                        0, NULL, project_directory, &startup, &process)) {
        DWORD error_code = GetLastError();
        DWORD chars = FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                                     NULL, error_code, 0, system_message,
                                     (DWORD)(sizeof(system_message) / sizeof(system_message[0])), NULL);
        copy_wide(error_message, MAX_PATH_BUFFER + 256,
                  L"O Windows nao conseguiu iniciar a Godot. Codigo de erro: ");
        /* The numeric code is optional; the Windows system explanation is more useful. */
        if (chars > 0) {
            append_wide(error_message, MAX_PATH_BUFFER + 256, L"\n\n");
            append_wide(error_message, MAX_PATH_BUFFER + 256, system_message);
        }
        show_error(L"BLACKSITE - falha ao iniciar", error_message);
        ExitProcess(6);
    }

    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    ExitProcess(0);
}

void WINAPI entrypoint(void) {
    launch_blacksite();
}
