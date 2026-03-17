<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between gap-4">
            <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-100 leading-tight">Settings</h2>
            <a href="{{ route('dashboard') }}" class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-100 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700">
                Back to Dashboard
            </a>
        </div>
    </x-slot>

    <div class="py-12">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8 space-y-6">
            <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow sm:rounded-lg">
                <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">Account Settings</h3>
                <p class="mt-1 text-sm text-gray-600 dark:text-gray-300">Manage profile details and password.</p>
                <div class="mt-4">
                    <a href="{{ route('profile.edit') }}" class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-100 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700">
                        Edit Profile
                    </a>
                </div>
            </div>

            <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow sm:rounded-lg">
                <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">Appearance</h3>
                <p class="mt-1 text-sm text-gray-600 dark:text-gray-300">Switch dark mode on or off.</p>
                <label class="mt-4 inline-flex items-center gap-3 cursor-pointer">
                    <input id="dark-mode-toggle" type="checkbox" class="rounded border-gray-300 text-indigo-600 shadow-sm focus:ring-indigo-500">
                    <span class="text-sm text-gray-700 dark:text-gray-200">Dark Mode</span>
                </label>
            </div>
        </div>
    </div>

    <script>
        (function () {
            const toggle = document.getElementById('dark-mode-toggle');
            if (!toggle) {
                return;
            }
            const darkMode = localStorage.getItem('darkMode') === 'true';
            toggle.checked = darkMode;
            document.documentElement.classList.toggle('dark', darkMode);

            toggle.addEventListener('change', function () {
                const enabled = toggle.checked;
                localStorage.setItem('darkMode', enabled ? 'true' : 'false');
                document.documentElement.classList.toggle('dark', enabled);
            });
        })();
    </script>
</x-app-layout>
