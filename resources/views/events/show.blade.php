<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between">
            <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-100 leading-tight">
                {{ $event->title }}
            </h2>
            <a href="{{ route('events.index') }}" class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600 transition">
                &larr; Back to Events
            </a>
        </div>
    </x-slot>

    <div class="py-8">
        <div class="max-w-5xl mx-auto sm:px-6 lg:px-8 space-y-6">

            {{-- Flash Messages --}}
            @if (session('success'))
                <div class="bg-green-50 dark:bg-green-900/30 border border-green-200 dark:border-green-800 rounded-lg p-4">
                    <p class="text-green-800 dark:text-green-200 text-sm">{{ session('success') }}</p>
                </div>
            @endif
            @if (session('error'))
                <div class="bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-800 rounded-lg p-4">
                    <p class="text-red-800 dark:text-red-200 text-sm">{{ session('error') }}</p>
                </div>
            @endif
            @if (session('info'))
                <div class="bg-blue-50 dark:bg-blue-900/30 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
                    <p class="text-blue-800 dark:text-blue-200 text-sm">{{ session('info') }}</p>
                </div>
            @endif

            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {{-- Main Content --}}
                <div class="lg:col-span-2 space-y-6">
                    {{-- Event Image --}}
                    <div class="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg">
                        @if($event->image)
                            <img src="{{ Storage::url($event->image) }}" alt="{{ $event->title }}" class="w-full h-64 object-cover">
                        @else
                            <div class="w-full h-64 bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center">
                                <svg class="w-20 h-20 text-white/60" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>
                            </div>
                        @endif
                    </div>

                    {{-- Event Details --}}
                    <div class="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg p-6">
                        <div class="flex items-center gap-2 mb-4">
                            @if($event->category)
                                <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-indigo-100 text-indigo-800 dark:bg-indigo-900/50 dark:text-indigo-300">
                                    {{ str_replace('_', ' ', ucfirst($event->category)) }}
                                </span>
                            @endif
                            <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium
                                @if($event->status === 'approved') bg-green-100 text-green-800 dark:bg-green-900/50 dark:text-green-300
                                @elseif($event->status === 'pending') bg-yellow-100 text-yellow-800 dark:bg-yellow-900/50 dark:text-yellow-300
                                @else bg-red-100 text-red-800 dark:bg-red-900/50 dark:text-red-300
                                @endif">
                                {{ ucfirst($event->status) }}
                            </span>
                        </div>

                        <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">{{ $event->title }}</h1>

                        <div class="mt-4 flex items-center text-sm text-gray-500 dark:text-gray-400">
                            <span>Organized by <strong class="text-gray-900 dark:text-gray-100">{{ $event->organizer->name }}</strong></span>
                        </div>

                        <div class="mt-6 prose dark:prose-invert max-w-none">
                            <p class="text-gray-700 dark:text-gray-300 whitespace-pre-line">{{ $event->description }}</p>
                        </div>
                    </div>

                    {{-- Announcements --}}
                    @if($event->announcements->isNotEmpty())
                        <div class="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg p-6">
                            <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">Announcements</h3>
                            <div class="space-y-4">
                                @foreach($event->announcements->sortByDesc('created_at') as $announcement)
                                    <div class="p-4 rounded-lg border border-gray-200 dark:border-gray-700">
                                        <div class="flex items-center justify-between mb-2">
                                            <h4 class="font-medium text-gray-900 dark:text-gray-100">{{ $announcement->title }}</h4>
                                            <span class="text-xs text-gray-500 dark:text-gray-400">{{ $announcement->created_at->diffForHumans() }}</span>
                                        </div>
                                        <p class="text-sm text-gray-600 dark:text-gray-400">{{ $announcement->body }}</p>
                                    </div>
                                @endforeach
                            </div>
                        </div>
                    @endif

                    {{-- Participants Preview --}}
                    <div class="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg p-6">
                        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
                            Participants ({{ $event->registrations_count }})
                        </h3>
                        @if($event->registrations->isEmpty())
                            <p class="text-sm text-gray-500 dark:text-gray-400">No participants yet. Be the first to register!</p>
                        @else
                            <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
                                @foreach($event->registrations->take(12) as $registration)
                                    <div class="flex items-center gap-2 p-2 rounded-lg bg-gray-50 dark:bg-gray-700/50">
                                        <div class="w-8 h-8 rounded-full bg-indigo-100 dark:bg-indigo-900/50 flex items-center justify-center text-sm font-medium text-indigo-700 dark:text-indigo-300">
                                            {{ strtoupper(substr($registration->user->name, 0, 1)) }}
                                        </div>
                                        <span class="text-sm text-gray-900 dark:text-gray-100 truncate">{{ $registration->user->name }}</span>
                                    </div>
                                @endforeach
                            </div>
                            @if($event->registrations_count > 12)
                                <p class="mt-3 text-sm text-gray-500 dark:text-gray-400">and {{ $event->registrations_count - 12 }} more...</p>
                            @endif
                        @endif
                    </div>
                </div>

                {{-- Sidebar --}}
                <div class="space-y-6">
                    {{-- Registration Card --}}
                    <div class="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg p-6">
                        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">Registration</h3>

                        <div class="space-y-3 mb-6">
                            <div class="flex items-center text-sm">
                                <svg class="w-5 h-5 mr-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>
                                <div>
                                    <p class="text-gray-500 dark:text-gray-400">Date</p>
                                    <p class="font-medium text-gray-900 dark:text-gray-100">{{ $event->starts_at?->format('M d, Y') ?? 'TBD' }}</p>
                                </div>
                            </div>
                            <div class="flex items-center text-sm">
                                <svg class="w-5 h-5 mr-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                                <div>
                                    <p class="text-gray-500 dark:text-gray-400">Time</p>
                                    <p class="font-medium text-gray-900 dark:text-gray-100">{{ $event->starts_at?->format('h:i A') ?? 'TBD' }} - {{ $event->ends_at?->format('h:i A') ?? 'TBD' }}</p>
                                </div>
                            </div>
                            @if($event->location)
                                <div class="flex items-center text-sm">
                                    <svg class="w-5 h-5 mr-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                                    <div>
                                        <p class="text-gray-500 dark:text-gray-400">Location</p>
                                        <p class="font-medium text-gray-900 dark:text-gray-100">{{ $event->location }}</p>
                                    </div>
                                </div>
                            @endif
                            <div class="flex items-center text-sm">
                                <svg class="w-5 h-5 mr-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                                <div>
                                    <p class="text-gray-500 dark:text-gray-400">Spots</p>
                                    <p class="font-medium text-gray-900 dark:text-gray-100">
                                        {{ $event->registrations_count }}/{{ $event->capacity ?? '∞' }}
                                        @if($event->spotsRemaining() !== null)
                                            <span class="text-gray-500 dark:text-gray-400">({{ $event->spotsRemaining() }} remaining)</span>
                                        @endif
                                    </p>
                                </div>
                            </div>
                            <div class="flex items-center text-sm">
                                <svg class="w-5 h-5 mr-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                                <div>
                                    <p class="text-gray-500 dark:text-gray-400">Fee</p>
                                    <p class="font-medium text-gray-900 dark:text-gray-100">
                                        @if($event->fee > 0)
                                            BND {{ number_format($event->fee, 2) }}
                                        @else
                                            Free
                                        @endif
                                    </p>
                                </div>
                            </div>
                            @if($event->registration_deadline)
                                <div class="flex items-center text-sm">
                                    <svg class="w-5 h-5 mr-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                                    <div>
                                        <p class="text-gray-500 dark:text-gray-400">Registration Deadline</p>
                                        <p class="font-medium text-gray-900 dark:text-gray-100">{{ $event->registration_deadline->format('M d, Y') }}</p>
                                    </div>
                                </div>
                            @endif
                        </div>

                        @auth
                            @if($isRegistered)
                                <div class="space-y-3">
                                    <div class="p-3 rounded-lg bg-green-50 dark:bg-green-900/30 border border-green-200 dark:border-green-800">
                                        <p class="text-sm font-medium text-green-800 dark:text-green-200">✓ You are registered for this event</p>
                                    </div>
                                    <a href="{{ route('events.qr-code', $event) }}" class="block w-full text-center px-4 py-3 bg-indigo-600 text-white font-medium rounded-lg hover:bg-indigo-700 transition">
                                        View My QR Code
                                    </a>
                                </div>
                            @elseif($event->user_id === auth()->id())
                                <a href="{{ route('events.manage.show', $event) }}" class="block w-full text-center px-4 py-3 bg-indigo-600 text-white font-medium rounded-lg hover:bg-indigo-700 transition">
                                    Manage This Event
                                </a>
                            @elseif($event->isFull())
                                <div class="p-3 rounded-lg bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-800">
                                    <p class="text-sm font-medium text-red-800 dark:text-red-200">This event is full</p>
                                </div>
                            @elseif(!$event->isRegistrationOpen())
                                <div class="p-3 rounded-lg bg-gray-50 dark:bg-gray-700/50 border border-gray-200 dark:border-gray-600">
                                    <p class="text-sm font-medium text-gray-800 dark:text-gray-200">Registration is closed</p>
                                </div>
                            @else
                                <a href="{{ route('events.register', $event) }}" class="block w-full text-center px-4 py-3 bg-indigo-600 text-white font-medium rounded-lg hover:bg-indigo-700 transition">
                                    Register for This Event
                                </a>
                            @endif
                        @else
                            <a href="{{ route('login') }}" class="block w-full text-center px-4 py-3 bg-indigo-600 text-white font-medium rounded-lg hover:bg-indigo-700 transition">
                                Log in to Register
                            </a>
                        @endauth
                    </div>

                    {{-- Organizer Info --}}
                    <div class="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg p-6">
                        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-3">Organizer</h3>
                        <div class="flex items-center gap-3">
                            <div class="w-10 h-10 rounded-full bg-indigo-100 dark:bg-indigo-900/50 flex items-center justify-center text-lg font-medium text-indigo-700 dark:text-indigo-300">
                                {{ strtoupper(substr($event->organizer->name, 0, 1)) }}
                            </div>
                            <div>
                                <p class="font-medium text-gray-900 dark:text-gray-100">{{ $event->organizer->name }}</p>
                                <p class="text-sm text-gray-500 dark:text-gray-400">Event Organizer</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
