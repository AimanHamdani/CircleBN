<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-100 leading-tight">
            Registration Confirmed!
        </h2>
    </x-slot>

    <div class="py-8">
        <div class="max-w-2xl mx-auto sm:px-6 lg:px-8">
            <div class="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg p-8 text-center">
                <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-green-100 dark:bg-green-900/50 flex items-center justify-center">
                    <svg class="w-8 h-8 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                </div>

                <h3 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-2">You're all set!</h3>
                <p class="text-gray-600 dark:text-gray-400 mb-6">You have successfully registered for <strong>{{ $event->title }}</strong>.</p>

                {{-- QR Code Section --}}
                <div class="p-6 rounded-lg bg-gray-50 dark:bg-gray-700/50 mb-6">
                    <p class="text-sm text-gray-500 dark:text-gray-400 mb-4">Your unique QR code for event day check-in:</p>
                    <div class="inline-block p-4 bg-white rounded-lg shadow-sm">
                        {{-- QR Code rendered as text (in production, use a QR library) --}}
                        <div class="w-48 h-48 flex items-center justify-center border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg">
                            <div class="text-center">
                                <svg class="w-12 h-12 mx-auto text-gray-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z"/></svg>
                                <p class="text-xs text-gray-500 font-mono break-all">{{ $registration->qr_code }}</p>
                            </div>
                        </div>
                    </div>
                </div>

                {{-- Event Details --}}
                <div class="text-left p-4 rounded-lg border border-gray-200 dark:border-gray-700 mb-6">
                    <h4 class="font-medium text-gray-900 dark:text-gray-100 mb-3">Event Details</h4>
                    <div class="space-y-2 text-sm">
                        <div class="flex justify-between">
                            <span class="text-gray-500 dark:text-gray-400">Event</span>
                            <span class="font-medium text-gray-900 dark:text-gray-100">{{ $event->title }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="text-gray-500 dark:text-gray-400">Date</span>
                            <span class="font-medium text-gray-900 dark:text-gray-100">{{ $event->starts_at?->format('M d, Y \a\t h:i A') ?? 'TBD' }}</span>
                        </div>
                        @if($event->location)
                            <div class="flex justify-between">
                                <span class="text-gray-500 dark:text-gray-400">Location</span>
                                <span class="font-medium text-gray-900 dark:text-gray-100">{{ $event->location }}</span>
                            </div>
                        @endif
                        <div class="flex justify-between">
                            <span class="text-gray-500 dark:text-gray-400">Registration ID</span>
                            <span class="font-mono text-gray-900 dark:text-gray-100">#{{ $registration->id }}</span>
                        </div>
                    </div>
                </div>

                <div class="flex justify-center gap-4">
                    <a href="{{ route('events.qr-code', $event) }}" class="inline-flex items-center px-6 py-2 bg-indigo-600 border border-transparent rounded-lg text-sm font-medium text-white hover:bg-indigo-700 transition">
                        View QR Code
                    </a>
                    <a href="{{ route('events.show', $event) }}" class="inline-flex items-center px-6 py-2 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg text-sm font-medium text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-600 transition">
                        Back to Event
                    </a>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
