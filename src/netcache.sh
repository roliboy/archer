cd /var/cache/pacman/pkg/

declare -A package_versions
declare -A package_files

echo loading package files
total_packages="$(ls *.pkg.tar.* | wc -l)"
echo -ne "0/$total_packages"
for package_file in *.pkg.tar.*; do
    i="$(expr $i + 1)"
    echo -ne "\r$i/$total_packages"
    package_size="$(du $package_file | awk '{print $1}')"
    [ "$package_size" -lt 1000 ] && continue
    package_name="$(pacman -Qip $package_file | grep Name | awk -F' : ' '{print $NF}')"
    package_version="$(pacman -Qip $package_file | grep Version | awk -F' : ' '{print $NF}')"
    if [[ "$package_version" > "${package_versions[$package_name]}" ]]; then
        package_versions[$package_name]="$package_version"
        package_files[$package_name]="$package_file"
    fi
done

for package in "${package_files[@]}"; do
    repo-add netcache.db.tar.gz "$package"
done

#TODO: threading and graceful server shutdown

echo 'Starting server...'

python -c '
import http.server
import socketserver

class NetCache(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/shutdown":
            exit(0)
        print("GET ", self.path)
        return http.server.SimpleHTTPRequestHandler.do_GET(self)

    def log_message(self, format, *args):
        pass

with socketserver.TCPServer(("", 1337), NetCache) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
'

rm netcache.db
rm netcache.db.tar.gz
rm netcache.files
rm netcache.files.tar.gz
