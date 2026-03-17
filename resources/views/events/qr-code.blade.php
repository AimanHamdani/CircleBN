<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-100 leading-tight">
            Your QR Code
        </h2>
    </x-slot>

    <div class="py-8">
        <div class="max-w-lg mx-auto sm:px-6 lg:px-8">
            <div class="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg p-8 text-center">
                <h3 class="text-xl font-bold text-gray-900 dark:text-gray-100 mb-1">{{ $event->title }}</h3>
                <p class="text-sm text-gray-500 dark:text-gray-400 mb-6">{{ $event->starts_at?->format('M d, Y \a\t h:i A') ?? 'TBD' }}</p>

                {{-- QR Code --}}
                <div class="inline-block p-6 bg-white rounded-xl shadow-md mb-6">
                    <canvas id="qr-canvas" class="mx-auto"></canvas>
                </div>

                <p class="text-xs text-gray-400 dark:text-gray-500 font-mono mb-6 break-all">{{ $registration->qr_code }}</p>

                <div class="text-sm text-gray-600 dark:text-gray-400 mb-6">
                    <p>Show this QR code at the event for quick check-in.</p>
                    <p class="mt-1 text-xs text-gray-400">You can also screenshot this page for offline access.</p>
                </div>

                <a href="{{ route('events.show', $event) }}" class="inline-flex items-center px-4 py-2 bg-gray-100 dark:bg-gray-700 rounded-lg text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-600 transition">
                    &larr; Back to Event
                </a>
            </div>
        </div>
    </div>

    @push('scripts')
    <script src="https://cdn.jsdelivr.net/npm/qrcode@1.5.4/build/qrcode.min.js"></script>
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            QRCode.toCanvas(document.getElementById('qr-canvas'), '{{ $registration->qr_code }}', {
                width: 240,
                margin: 2,
                color: { dark: '#000000', light: '#ffffff' }
            });
        });
    </script>
    @endpush
</x-app-layout>
