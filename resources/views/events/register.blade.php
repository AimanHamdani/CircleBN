<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between">
            <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-100 leading-tight">
                Register for {{ $event->title }}
            </h2>
            <a href="{{ route('events.show', $event) }}" class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600 transition">
                &larr; Back to Event
            </a>
        </div>
    </x-slot>

    <div class="py-8">
        <div class="max-w-3xl mx-auto sm:px-6 lg:px-8">
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {{-- Registration Form --}}
                <div class="lg:col-span-2">
                    <div class="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg p-6">
                        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">Registration Form</h3>
                        <p class="text-sm text-gray-500 dark:text-gray-400 mb-6">Your name and email are pre-filled from your profile for quick registration.</p>

                        <form method="POST" action="{{ route('events.register.store', $event) }}" class="space-y-6">
                            @csrf

                            {{-- Pre-filled fields (read-only) --}}
                            <div class="p-4 rounded-lg bg-gray-50 dark:bg-gray-700/50 space-y-3">
                                <p class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">From your profile</p>
                                <div class="grid grid-cols-2 gap-4">
                                    <div>
                                        <x-input-label value="Name" />
                                        <p class="mt-1 font-medium text-gray-900 dark:text-gray-100">{{ $user->name }}</p>
                                    </div>
                                    <div>
                                        <x-input-label value="Email" />
                                        <p class="mt-1 font-medium text-gray-900 dark:text-gray-100">{{ $user->email }}</p>
                                    </div>
                                </div>
                            </div>

                            {{-- Gender --}}
                            <div>
                                <x-input-label for="gender" value="Gender" />
                                <select id="gender" name="gender" class="mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 shadow-sm focus:ring-indigo-500 focus:border-indigo-500" required>
                                    <option value="">Select gender</option>
                                    <option value="male" @selected(old('gender') === 'male')>Male</option>
                                    <option value="female" @selected(old('gender') === 'female')>Female</option>
                                    <option value="other" @selected(old('gender') === 'other')>Other</option>
                                </select>
                                <x-input-error :messages="$errors->get('gender')" class="mt-2" />
                            </div>

                            {{-- Age --}}
                            <div>
                                <x-input-label for="age" value="Age" />
                                <x-text-input id="age" name="age" type="number" class="mt-1 block w-full" :value="old('age')" min="1" max="120" required />
                                <x-input-error :messages="$errors->get('age')" class="mt-2" />
                            </div>

                            {{-- Emergency Contact --}}
                            <div>
                                <x-input-label for="emergency_contact" value="Emergency Contact Number" />
                                <x-text-input id="emergency_contact" name="emergency_contact" type="text" class="mt-1 block w-full" :value="old('emergency_contact')" required placeholder="+673 XXXXXXX" />
                                <x-input-error :messages="$errors->get('emergency_contact')" class="mt-2" />
                            </div>

                            {{-- T-Shirt Size --}}
                            <div>
                                <x-input-label for="tshirt_size" value="T-Shirt Size (optional)" />
                                <select id="tshirt_size" name="tshirt_size" class="mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 shadow-sm focus:ring-indigo-500 focus:border-indigo-500">
                                    <option value="">Select size</option>
                                    <option value="XS" @selected(old('tshirt_size') === 'XS')>XS</option>
                                    <option value="S" @selected(old('tshirt_size') === 'S')>S</option>
                                    <option value="M" @selected(old('tshirt_size') === 'M')>M</option>
                                    <option value="L" @selected(old('tshirt_size') === 'L')>L</option>
                                    <option value="XL" @selected(old('tshirt_size') === 'XL')>XL</option>
                                    <option value="XXL" @selected(old('tshirt_size') === 'XXL')>XXL</option>
                                </select>
                                <x-input-error :messages="$errors->get('tshirt_size')" class="mt-2" />
                            </div>

                            <div class="flex items-center justify-end gap-4 pt-4 border-t border-gray-200 dark:border-gray-700">
                                <a href="{{ route('events.show', $event) }}" class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600 transition">
                                    Cancel
                                </a>
                                <button type="submit" class="inline-flex items-center px-6 py-2 bg-indigo-600 border border-transparent rounded-lg text-sm font-medium text-white hover:bg-indigo-700 transition">
                                    Confirm Registration
                                </button>
                            </div>
                        </form>
                    </div>
                </div>

                {{-- Event Summary Sidebar --}}
                <div>
                    <div class="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg p-6">
                        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">Event Summary</h3>
                        <div class="space-y-3 text-sm">
                            <div>
                                <p class="text-gray-500 dark:text-gray-400">Event</p>
                                <p class="font-medium text-gray-900 dark:text-gray-100">{{ $event->title }}</p>
                            </div>
                            <div>
                                <p class="text-gray-500 dark:text-gray-400">Date</p>
                                <p class="font-medium text-gray-900 dark:text-gray-100">{{ $event->starts_at?->format('M d, Y') ?? 'TBD' }}</p>
                            </div>
                            @if($event->location)
                                <div>
                                    <p class="text-gray-500 dark:text-gray-400">Location</p>
                                    <p class="font-medium text-gray-900 dark:text-gray-100">{{ $event->location }}</p>
                                </div>
                            @endif
                            <div class="pt-3 border-t border-gray-200 dark:border-gray-700">
                                <p class="text-gray-500 dark:text-gray-400">Fee</p>
                                <p class="text-lg font-bold text-gray-900 dark:text-gray-100">
                                    @if($event->fee > 0)
                                        BND {{ number_format($event->fee, 2) }}
                                    @else
                                        Free
                                    @endif
                                </p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
