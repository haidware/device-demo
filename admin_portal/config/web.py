from django.conf import settings
from django.http import FileResponse
from django.shortcuts import redirect


def flutter_home(request):
    index_file = settings.WHITENOISE_ROOT / "index.html"
    if index_file.is_file():
        return FileResponse(index_file.open("rb"))
    return redirect("dashboard")
