<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between">
            <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-100 leading-tight">
                Check-in &mdash; {{ $event->title }}
            </h2>
            <a href="{{ route('events.manage.show', $event) }}" class="text-sm text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 transition">&larr; Back to Dashboard</a>
        </div>
    </x-slot>

    <div class="py-8">
        <div class="max-w-5xl mx-auto sm:px-6 lg:px-8 space-y-6" x-data="checkInApp()">
            {{-- Stats Bar --}}
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-4 text-center">
                    <p class="text-xs text-gray-500 dark:text-gray-400 uppercase">Total</p>
                    <p class="text-2xl font-bold text-gray-900 dark:text-gray-100" x-text="totalRegistered">{{ $event->registrations_count }}</p>
                </div>
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-4 text-center">
                    <p class="text-xs text-gray-500 dark:text-gray-400 uppercase">Checked In</p>
                    <p class="text-2xl font-bold text-green-600 dark:text-green-400" x-text="totalCheckedIn">{{ $checkedInCount }}</p>
                </div>
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-4 text-center">
                    <p class="text-xs text-gray-500 dark:text-gray-400 uppercase">Remaining</p>
                    <p class="text-2xl font-bold text-yellow-600 dark:text-yellow-400" x-text="totalRegistered - totalCheckedIn">{{ $event->registrations_count - $checkedInCount }}</p>
                </div>
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-4 text-center">
                    <p class="text-xs text-gray-500 dark:text-gray-400 uppercase">Rate</p>
                    <p class="text-2xl font-bold text-indigo-600 dark:text-indigo-400" x-text="totalRegistered > 0 ? Math.round((totalCheckedIn / totalRegistered) * 100) + '%' : '0%'">
                        {{ $event->registrations_count > 0 ? round(($checkedInCount / $event->registrations_count) * 100) . '%' : '0%' }}
                    </p>
                </div>
            </div>

            {{-- QR Scanner & Manual Entry --}}
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {{-- QR Scanner --}}
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6">
                    <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">QR Code Scanner</h3>

                    <div class="space-y-4">
                        <div>
                            <label for="qr-input" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Scan or paste QR code</label>
                            <div class="flex gap-2">
                                <input type="text" id="qr-input" x-model="qrCode" @keydown.enter="scanQr()"
                                    placeholder="Scan QR code here..."
                                    class="flex-1 rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-sm focus:ring-indigo-500 focus:border-indigo-500"
                                    autofocus>
                                <button @click="scanQr()" :disabled="scanning"
                                    class="px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700 disabled:opacity-50 transition">
                                    <span x-show="!scanning">Check In</span>
                                    <span x-show="scanning">...</span>
                                </button>
                            </div>
                        </div>

                        {{-- Result Message --}}
                        <div x-show="message" x-transition
                            :class="{
                                'bg-green-50 dark:bg-green-900/30 border-green-200 dark:border-green-700 text-green-700 dark:text-green-300': success,
                                'bg-red-50 dark:bg-red-900/30 border-red-200 dark:border-red-700 text-red-700 dark:text-red-300': !success
                            }"
                            class="p-4 rounded-lg border text-sm">
                            <div class="flex items-center gap-2">
                                <template x-if="success">
                                    <svg class="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                                </template>
                                <template x-if="!success">
                                    <svg class="w-5 h-5 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                                </template>
                                <span x-text="message"></span>
                            </div>
                        </div>
                    </div>
                </div>

                {{-- Manual Check-in --}}
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6">
                    <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Manual Check-in</h3>
                    <p class="text-sm text-gray-500 dark:text-gray-400 mb-4">Search and check in participants manually.</p>

                    <div class="mb-4">
                        <input type="text" x-model="searchTerm" placeholder="Search by name or email..."
                            class="w-full rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-sm focus:ring-indigo-500 focus:border-indigo-500">
                    </div>

                    <div class="max-h-64 overflow-y-auto space-y-2">
                        @foreach($event->registrations as $registration)
                            <div class="flex items-center justify-between p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700/50 transition"
                                x-show="!searchTerm || '{{ strtolower($registration->user->name . ' ' . $registration->user->email) }}'.includes(searchTerm.toLowerCase())">
                                <div>
                                    <p class="text-sm font-medium text-gray-900 dark:text-gray-100">{{ $registration->user->name }}</p>
                                    <p class="text-xs text-gray-500 dark:text-gray-400">{{ $registration->user->email }}</p>
                                </div>
                                @if($registration->checked_in_at)
                                    <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900/50 dark:text-green-300">
                                        &#10003; Checked In
                                    </span>
                                @else
                                    <button @click="manualCheckIn({{ $registration->id }})"
                                        class="px-3 py-1.5 bg-indigo-600 text-white text-xs font-medium rounded-lg hover:bg-indigo-700 transition">
                                        Check In
                                    </button>
                                @endif
                            </div>
                        @endforeach
                    </div>
                </div>
            </div>
        </div>
    </div>

    @push('scripts')
    <script>
        function checkInApp() {
            return {
                qrCode: '',
                scanning: false,
                message: '',
                success: false,
                searchTerm: '',
                totalRegistered: {{ $event->registrations_count }},
                totalCheckedIn: {{ $checkedInCount }},

                async scanQr() {
                    if (!this.qrCode.trim() || this.scanning) return;
                    this.scanning = true;
                    this.message = '';

                    try {
                        const response = await fetch('{{ route("events.manage.checkin.scan", $event) }}', {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json',
                                'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                                'Accept': 'application/json',
                            },
                            body: JSON.stringify({ qr_code: this.qrCode }),
                        });

                        const data = await response.json();
                        this.message = data.message;
                        this.success = data.success;

                        if (data.total_registered) this.totalRegistered = data.total_registered;
                        if (data.total_checked_in) this.totalCheckedIn = data.total_checked_in;

                        if (data.success) this.qrCode = '';
                    } catch (error) {
                        this.message = 'Network error. Please try again.';
                        this.success = false;
                    }

                    this.scanning = false;
                    this.$nextTick(() => document.getElementById('qr-input').focus());
                },

                async manualCheckIn(registrationId) {
                    try {
                        const response = await fetch('{{ route("events.manage.checkin.manual", $event) }}', {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json',
                                'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                                'Accept': 'application/json',
                            },
                            body: JSON.stringify({ registration_id: registrationId }),
                        });

                        const data = await response.json();
                        this.message = data.message;
                        this.success = data.success;

                        if (data.success) {
                            this.totalCheckedIn++;
                            location.reload();
                        }
                    } catch (error) {
                        this.message = 'Network error. Please try again.';
                        this.success = false;
                    }
                }
            };
        }
    </script>
    @endpush
</x-app-layout>
